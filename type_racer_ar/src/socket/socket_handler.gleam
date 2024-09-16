import actors/lobby.{type LobbyMsg, LGetResult, LMovePlayer}
import actors/lobby_orchestrator.{type LobbyOrchestratorMsg, LOJoinLobbyRequest}
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/otp/actor
import gleam/string
import mist.{type Connection, type ResponseData}
import prng/random.{type Generator}
import prng/seed
import utils/serialization.{
  type ClientMessageCommand, JoinLobbyRequest, MovePlayer, decode_message,
  dict_to_string,
}

pub type SocketState {
  SocketState(
    lobby_orchestrator_actor: process.Subject(LobbyOrchestratorMsg),
    player_id: String,
    player_name: String,
    id_gen: Generator(Int),
  )
}

pub fn handle_ws_message(state: SocketState, conn, message) {
  case message {
    mist.Text("ping") -> {
      let assert Ok(_) = mist.send_text_frame(conn, "pong")
      io.debug(state)
      io.debug(conn)
      actor.continue(state)
    }
    mist.Text(json_string) -> {
      let message_decoded = decode_message(json_string)
      io.debug(message_decoded)
      let result = case message_decoded {
        Ok(message_command) -> {
          case message_command {
            JoinLobbyRequest(player_name, player_uuid, car_id) -> {
              let player_uuid_resolved =
                get_player_id(player_uuid, player_name, state)

              io.debug(state)
              let lo_actor_message =
                LOJoinLobbyRequest(
                  player_name,
                  player_uuid_resolved,
                  car_id,
                  conn,
                )

              process.send(state.lobby_orchestrator_actor, lo_actor_message)

              let new_state =
                SocketState(
                  ..state,
                  player_name: player_name,
                  player_id: player_uuid_resolved,
                )

              let assert Ok(_) =
                mist.send_text_frame(conn, player_uuid_resolved)

              actor.continue(new_state)
            }
            MovePlayer(progress) -> {
              io.debug(state)
              //   process.send(state.lobby_orchestrator_actor, message_command)

              //   //TODO
              //   let assert Ok(_) =
              //     mist.send_text_frame(conn, "New Table of Positions")
              //   let lobby_state =
              //     process.call(state.lobby_orchestrator_actor, GetResult, 100)
              //   //   let dict_str = dict_to_string(lobby_state.player_progress)
              actor.continue(state)
              //   //   let assert Ok(_) = mist.send_text_frame(conn, dict_str)
            }
          }
        }
        Error(_) -> {
          let assert Ok(_) = mist.send_text_frame(conn, "error")
          actor.continue(state)
        }
      }
    }
    mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
    _ | mist.Text(_) | mist.Binary(_) -> {
      io.debug("welp nothing happened")
      actor.continue(state)
    }
  }
}

pub fn get_player_id(
  player_uuid: String,
  player_name: String,
  state: SocketState,
) -> String {
  case player_uuid {
    "" -> {
      case state.player_id {
        "" -> {
          // create user id
          let #(random_int, updated_seed) =
            state.id_gen |> random.step(seed.random())
          let random_id = int.to_string(random_int)
          let new_player_uuid = player_name <> "_" <> random_id
          new_player_uuid
        }
        _ -> state.player_id
      }
    }
    _ -> {
      player_uuid
    }
  }
}
