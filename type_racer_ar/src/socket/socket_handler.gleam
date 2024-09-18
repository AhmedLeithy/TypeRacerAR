import actors/lobby
import actors/lobby_orchestrator
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option
import gleam/otp/actor
import gleam/string
import mist.{type Connection, type ResponseData}
import models/lobby_models
import prng/random.{type Generator}
import prng/seed
import utils/serialization.{
  type ClientMessageCommand, JoinLobbyRequest, MovePlayer, decode_message,
  dict_to_string,
}

pub type SocketState {
  SocketState(
    lobby_orchestrator_actor: process.Subject(lobby_models.LobbyOrchestratorMsg),
    player_id: String,
    player_name: String,
    id_gen: Generator(Int),
    ws_subject: process.Subject(lobby_models.MessageToClient),
  )
}

pub fn on_init_with_orch(
  lobby_orchestrator_actor: process.Subject(lobby_models.LobbyOrchestratorMsg),
) -> fn(mist.WebsocketConnection) ->
  #(SocketState, option.Option(process.Selector(lobby_models.MessageToClient))) {
  io.debug("on_init_with_orch")
  fn(connection: mist.WebsocketConnection) -> #(
    SocketState,
    option.Option(process.Selector(lobby_models.MessageToClient)),
  ) {
    io.debug("on_init")
    let gen = random.int(0, 10_000_000_000)
    let ws_subject = process.new_subject()
    let selector =
      process.new_selector()
      |> process.selecting(
        ws_subject,
        fn(message_to_client: lobby_models.MessageToClient) {
          // io.debug("Sending this to client " <> message_to_client.message)
          message_to_client
        },
      )
    #(
      SocketState(lobby_orchestrator_actor, "", "", gen, ws_subject),
      option.Some(selector),
    )
  }
}

pub fn handle_ws_message(state: SocketState, conn, message) {
  case message {
    mist.Text("ping") -> {
      let assert Ok(_) = mist.send_text_frame(conn, "pong")
      // io.debug(state)
      // io.debug(conn)
      // process.sleep_forever()
      // io.debug("ay 7aga")
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

              let new_player =
                lobby_models.Player(
                  player_name: player_name,
                  player_uuid: player_uuid_resolved,
                  car_id: car_id,
                  progress: 0.0,
                  connection: conn,
                  ws_subject: state.ws_subject,
                  play_time: option.None,
                )
              io.debug(new_player)
              let lo_actor_message = lobby_models.LOJoinLobbyRequest(new_player)
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
              process.send(
                state.lobby_orchestrator_actor,
                lobby_models.LOMovePlayer(state.player_id, progress),
              )
              io.debug(state)

              actor.continue(state)
            }
          }
        }
        Error(_) -> {
          let assert Ok(_) = mist.send_text_frame(conn, "error")
          actor.continue(state)
        }
      }
    }
    mist.Custom(lobby_models.MessageToClient(conn, message_string)) -> {
      mist.send_text_frame(conn, message_string)
      actor.continue(state)
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
