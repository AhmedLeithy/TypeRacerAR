import birl
import birl/duration
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/io
import gleam/iterator
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/otp/actor
import mist
import models/lobby_models
import prng/random
import prng/seed
import records/game.{type GameStatus, Finished, Pending, Running}
import utils/constants.{
  max_game_duration, max_player_limit, max_wait_duration, sentences,
}
import utils/serialization

// Handle messages
pub fn lobby_handle_message(
  msg: lobby_models.LobbyMsg,
  state: lobby_models.LobbyState,
) -> actor.Next(lobby_models.LobbyMsg, lobby_models.LobbyState) {
  case msg {
    lobby_models.LMovePlayer(player_uuid, new_progress) -> {
      case state.status {
        Running -> {
          io.debug("Move status")
          // CHECK CURRENT GAME STATE
          move_player_and_update_state(state, player_uuid, new_progress)
          |> actor.continue()
        }
        _ -> {
          io.debug("WHY YOU SEND MOVE COMMAND WITH LOBBY FINISHED")
          actor.continue(state)
        }
      }
    }
    lobby_models.LGetResult -> {
      case state.status {
        Pending -> {
          let new_state =
            check_if_time_to_run(state, None, lobby_models.Success)
          actor.continue(new_state)
        }
        Running -> {
          send_updates(state)
          actor.continue(state)
        }
        Finished -> {
          io.debug("Warning: send status reached finished lobby")
          actor.continue(state)
        }
      }
    }
    lobby_models.LAddPlayer(player, client) -> {
      let new_state = add_player(state, client, player)
      io.debug("STATE AFTER ADD PLAYER")
      io.debug(new_state)
      actor.continue(new_state)
    }
    lobby_models.LRemovePlayer(player_uuid, client) -> {
      // Remove player from progress dict
      let new_dict =
        state.player_progress
        |> dict.delete(player_uuid)

      let player_count =
        new_dict
        |> dict.size()

      let new_state =
        lobby_models.LobbyState(..state, player_progress: new_dict)

      case player_count {
        0 -> {
          case new_state.status {
            Pending -> {
              io.debug("REMOVED LOBBY TO EMPTY BUT DIDNT KILL CUZ PENDING")
              process.send(client, lobby_models.RemovedPlayer)
              actor.continue(
                lobby_models.LobbyState(
                  ..new_state,
                  start_waiting_time: None,
                  start_time: None,
                ),
              )
            }
            _ -> {
              io.debug("REMOVED LOBBY TO EMPTY AND KILLED LOBBY")
              process.send(client, lobby_models.RemovedPlayerAndKilledLobby)
              actor.Stop(process.Normal)
            }
          }
        }
        _ -> {
          io.debug(
            "REMOVED LOBBY TO EMPTY AND DIDNT KILL BECAUSE OTHER PLAYERS EXIST",
          )
          process.send(client, lobby_models.RemovedPlayer)
          case new_state.status {
            Pending -> {
              send_updates(new_state)
            }
            _ -> {
              Nil
            }
          }

          actor.continue(new_state)
        }
      }
    }
    lobby_models.LGetStatusInternal(client) -> {
      process.send(client, state.status)
      actor.continue(state)
    }
  }
}

// FUNCTION MUST UPDATE THE CLIENT
pub fn add_player(
  state: lobby_models.LobbyState,
  client: Subject(lobby_models.LobbyAddPlayerResult),
  player: lobby_models.Player,
) -> lobby_models.LobbyState {
  case state.status {
    Pending -> {
      // check if user already in list
      let player_already_waiting =
        state.player_progress
        |> dict.has_key(player.player_uuid)

      case player_already_waiting {
        False -> {
          io.debug("Added player to lobby: " <> player.player_uuid)
          let new_dict =
            state.player_progress
            |> dict.insert(player.player_uuid, player)

          let waiting_player_count = new_dict |> dict.size()
          let new_waiting_time = case waiting_player_count {
            1 -> {
              Some(birl.utc_now())
            }
            _ -> {
              state.start_waiting_time
            }
          }
          let new_state =
            lobby_models.LobbyState(
              ..state,
              start_waiting_time: new_waiting_time,
              player_progress: new_dict,
            )

          io.debug("new __ STATE -> ")
          io.debug(new_state)
          send_updates(new_state)

          // Check if should start
          let final_state =
            check_if_should_run_after_adding_player(
              new_state,
              client,
              lobby_models.Success,
            )
          final_state
        }
        True -> {
          io.debug("player already waiting: " <> player.player_uuid)
          process.send(client, lobby_models.AlreadyAdded)
          state
        }
      }
    }
    _ -> {
      process.send(client, lobby_models.AlreadyStarted)
      state
    }
  }
}

pub fn create_new_empty_lobby(gen: random.Generator(Int)) -> lobby_models.Lobby {
  // gen id
  let #(random_int, _) = gen |> random.step(seed.random())
  let lobby_id = "game_lobby_" <> int.to_string(random_int)

  // lobby message
  let lobby_init_state =
    lobby_models.LobbyState(Pending, None, None, dict.new())
  let assert Ok(new_lobby_actor) =
    actor.start(lobby_init_state, lobby_handle_message)
  lobby_models.Lobby(lobby_id, new_lobby_actor)
}

pub fn check_if_time_to_run(
  state: lobby_models.LobbyState,
  optional_client: option.Option(Subject(lobby_models.LobbyAddPlayerResult)),
  default_add_player_result,
) -> lobby_models.LobbyState {
  // check time
  case state.start_waiting_time {
    Some(time_value) -> {
      let from_start_to_now = birl.difference(birl.utc_now(), time_value)
      let order = duration.compare(from_start_to_now, max_wait_duration)
      io.debug(from_start_to_now)
      case order {
        order.Lt -> {
          case optional_client {
            Some(client) -> process.send(client, default_add_player_result)
            None -> Nil
          }
          state
        }
        _ -> {
          let new_state = start_lobby(state)
          case optional_client {
            Some(client) -> process.send(client, lobby_models.AddedWillStart)
            None -> Nil
          }
          new_state
        }
      }
    }
    None -> {
      case optional_client {
        Some(client) -> process.send(client, default_add_player_result)
        None -> Nil
      }
      state
    }
  }
}

// FUNCTION MUST UPDATE THE CLIENT
pub fn check_if_should_run_after_adding_player(
  state: lobby_models.LobbyState,
  client: Subject(lobby_models.LobbyAddPlayerResult),
  default_add_player_result: lobby_models.LobbyAddPlayerResult,
) -> lobby_models.LobbyState {
  // Max user count reached
  let waiting_user_count =
    state.player_progress
    |> dict.size()
  case waiting_user_count {
    i if i == max_player_limit -> {
      let new_state = start_lobby(state)
      process.send(client, lobby_models.AddedWillStart)
      new_state
    }
    i if i < max_player_limit -> {
      check_if_time_to_run(state, Some(client), default_add_player_result)
    }
    i if i > max_player_limit -> {
      io.debug("ERROR!! LobbyAlready full")
      process.send(client, lobby_models.LobbyFull)
      state
    }

    _ -> {
      io.debug("How is it not greater than, less than or equal")
      state
    }
  }
}

pub fn start_lobby(state: lobby_models.LobbyState) -> lobby_models.LobbyState {
  let new_state =
    lobby_models.LobbyState(
      ..state,
      status: Running,
      start_time: Some(birl.utc_now()),
    )
  send_start_game_message(new_state)
  send_updates(new_state)
  new_state
}

// 1 - Send update when lobby is joined (when pending) 
// 2 - Send update when other players join (when pending) ( same as 1)
// 3 -  Send update when game started + Words
// 4 - Send Periodic Update with game status
// 5 - Send terminal Status

pub fn send_updates(state: lobby_models.LobbyState) {
  state.player_progress
  |> dict.each(fn(player_uuid, player) {
    let conn = player.connection
    process.send(
      player.ws_subject,
      lobby_models.MessageToClient(
        player.connection,
        serialization.seriailize_game_state(state, player_uuid),
      ),
    )
    // process.send(
    //   state.main_thread_subject,
    //   lobby_models.MessageToClient(conn, "A"),
    // )
  })
}

fn send_start_game_message(state: lobby_models.LobbyState) {
  let words_response = generate_words()
  let gen =
    serialization.serialize(
      constants.join_response_type,
      json.array(words_response, json.string),
    )
  state.player_progress
  |> dict.each(fn(player_uuid, player) {
    let conn = player.connection
    process.send(
      player.ws_subject,
      lobby_models.MessageToClient(player.connection, gen),
    )
  })
  state
}

fn generate_words() -> List(String) {
  case sentences {
    [first_element, ..rest] -> {
      let gen = random.uniform(first_element, rest)
      let iterator = random.to_random_iterator(gen)

      iterator
      |> iterator.take(up_to: 10)
      |> iterator.to_list
    }
    _ -> {
      ["Issue", "With", "Backend", "!"]
    }
  }
}

fn move_player_and_update_state(
  state: lobby_models.LobbyState,
  player_uuid: String,
  new_progress: Float,
) -> lobby_models.LobbyState {
  let find_player =
    state.player_progress
    |> dict.get(player_uuid)

  case find_player {
    Ok(player) -> {
      let new_player =
        update_player_after_progress_update(state, player, new_progress)
      let new_dict =
        state.player_progress
        |> dict.insert(player.player_uuid, new_player)

      lobby_models.LobbyState(..state, player_progress: new_dict)
      |> update_game_state_after_progress_update(new_dict)
    }
    Error(e) -> {
      io.debug("PLAYER NOT FOUND IN LOBBY PROGRESSION QUEUE")
      state
    }
  }
}

fn update_game_state_after_progress_update(
  state: lobby_models.LobbyState,
  dict: dict.Dict(string, lobby_models.Player),
) -> lobby_models.LobbyState {
  let all_done =
    dict
    |> dict.fold(True, fn(accumulator, key, value) {
      accumulator && value.progress == 100.0
    })

  case all_done {
    True -> {
      end_lobby(state)
    }
    False -> {
      state
    }
  }
}

fn end_lobby(state) {
  let end_state = lobby_models.LobbyState(..state, status: game.Finished)
  send_updates(end_state)

  // write to database 
  // ye2fel connections

  end_state
}

fn update_player_after_progress_update(
  state: lobby_models.LobbyState,
  player: lobby_models.Player,
  new_progress: Float,
) -> lobby_models.Player {
  case new_progress {
    100.0 -> {
      let play_time = case state.start_time {
        Some(time) -> {
          birl.difference(birl.utc_now(), time)
        }
        None -> {
          io.debug("NO START TIME FOUND.. DISASTER")
          duration.milli_seconds(0)
        }
      }

      io.debug(play_time)
      lobby_models.Player(
        ..player,
        progress: new_progress,
        play_time: Some(play_time),
      )
    }
    _ -> {
      lobby_models.Player(..player, progress: new_progress)
    }
  }
}
