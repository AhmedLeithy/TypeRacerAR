import actors/lobby.{type LobbyMsg, LGetResult, LMovePlayer}
import actors/lobby_orchestrator.{type LobbyOrchestratorMsg, LOJoinLobbyRequest}
import gleam/dict
import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import gleam/string
import mist.{type Connection, type ResponseData}
import utils/serialization.{
  type ClientMessageCommand, JoinLobbyRequest, MovePlayer, decode_message,
  dict_to_string,
}

pub type SocketState {
  SocketState(
    lobby_orchestrator_actor: process.Subject(LobbyOrchestratorMsg),
    player_id: String,
    player_name: String,
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
              //   let receive = Subject(String)
              io.debug(state)
              let lo_actor_message =
                LOJoinLobbyRequest(
                  player_name,
                  player_uuid,
                  car_id,
                  conn,
                  //   receive,
                )
              //   let player_id =
              process.send(state.lobby_orchestrator_actor, lo_actor_message)

              let new_state =
                SocketState(
                  ..state,
                  player_name: player_name,
                  player_id: player_uuid,
                )
              actor.continue(new_state)
            }
            MovePlayer(x, y) -> {
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
