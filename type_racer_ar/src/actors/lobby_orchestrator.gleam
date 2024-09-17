import actors/lobby
import birl
import birl/duration.{Duration}
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/option
import gleam/otp/actor
import mist.{type WebsocketConnection}
import models/lobby_models
import prng/random
import records/player.{type Player}

// Handle messages
pub fn lobby_orchestrator_handle_message(
  lobby_orchestrator_msg: lobby_models.LobbyOrchestratorMsg,
  state: lobby_models.LobbyOrchestratorState,
) -> actor.Next(
  lobby_models.LobbyOrchestratorMsg,
  lobby_models.LobbyOrchestratorState,
) {
  case lobby_orchestrator_msg {
    lobby_models.LOJoinLobbyRequest(
      player_name,
      player_uuid,
      car_id,
      connection,
    ) -> {
      let new_state =
        add_waiting_user(player_uuid, player_name, car_id, connection, state)
      io.debug(new_state)
      actor.continue(new_state)
      // Ready includes status + {pllayer uuid}
    }
    lobby_models.LOMovePlayer(player_uuid, new_progress) -> {
      // TODO
      let lobby =
        state.player_to_lobby
        |> dict.get(player_uuid)

      actor.continue(state)
    }
    lobby_models.LOGetResult -> {
      send_lobby_status_request(state.waiting_lobby)
      list.each(state.active_lobbies, fn(lby) { send_lobby_status_request(lby) })
      actor.continue(state)
    }
  }
}

fn send_lobby_status_request(lobby: lobby_models.Lobby) {
  process.send(lobby.actor, lobby_models.LGetResult)
}

fn add_waiting_user(
  player_uuid: String,
  player_name: String,
  car_id: Int,
  conn: WebsocketConnection,
  state: lobby_models.LobbyOrchestratorState,
) -> lobby_models.LobbyOrchestratorState {
  // CALL CHECK IF WE CAN START LOBBY
  // should_start_lobby(state)
  let player =
    player.Player(player_name, player_uuid, car_id, conn, option.None)

  let subject = process.new_subject()

  let add_player_state =
    process.send(
      state.waiting_lobby.actor,
      lobby_models.LAddPlayer(player, subject),
    )
  let add_player_result = process.receive(subject, within: 100)
  let new_state = case add_player_result {
    Ok(add_player_result_ok) -> {
      case add_player_result_ok {
        lobby_models.Success -> {
          io.debug("LO: Successfully added play")
          state
        }
        lobby_models.AlreadyAdded -> {
          io.debug("LO: Already Added")
          state
        }
        lobby_models.AddedWillStart -> {
          io.debug("LO: Successfully added, will start game")
          start_waiting_lobby(state)
        }
        lobby_models.LobbyFull -> {
          io.debug(
            "LO: LOBBY FULL SHOULDNT HAPPEN UNLESS RACE CONDITION OR LOGICAL ERROR",
          )
          let new_state = start_waiting_lobby(state)
          add_waiting_user(player_uuid, player_name, car_id, conn, new_state)
        }
        lobby_models.AlreadyStarted -> {
          io.debug(
            "LO: LOBBY ALREADY STARTED SHOULDNT HAPPEN UNLESS RACE CONDITION OR LOGICAL ERROR",
          )
          start_waiting_lobby(state)
          let new_state = start_waiting_lobby(state)
          add_waiting_user(player_uuid, player_name, car_id, conn, new_state)
        }
      }
    }
    Error(e) -> {
      io.debug("LO: ADD PLAYER STATE NOT OKAY")
      state
    }
  }

  new_state
  // try add player to waiting lobby
}

fn start_waiting_lobby(
  state: lobby_models.LobbyOrchestratorState,
) -> lobby_models.LobbyOrchestratorState {
  let new_list = [state.waiting_lobby, ..state.active_lobbies]
  let new_waiting_lobby =
    lobby.create_new_empty_lobby(random.int(0, 10_000_000))
  lobby_models.LobbyOrchestratorState(
    ..state,
    waiting_lobby: new_waiting_lobby,
    active_lobbies: new_list,
  )
}
