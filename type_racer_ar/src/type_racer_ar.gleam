import actors/lobby.{create_new_empty_lobby}
import actors/lobby_orchestrator.{lobby_orchestrator_handle_message}
import birl
import birl/duration
import gleam/bit_array
import gleam/bytes_builder
import gleam/dict
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/json
import gleam/option.{None, Some}
import gleam/order
import gleam/otp/actor
import mist.{type Connection, type ResponseData}
import models/lobby_models
import prng/random
import socket/socket_handler.{SocketState, handle_ws_message, on_init_with_orch}

pub fn main() {
  let main_process_subject = process.new_subject()

  // These values are for the Websocket process initialized below
  let selector =
    process.new_selector()
    |> process.selecting(
      main_process_subject,
      fn(message_to_client: lobby_models.MessageToClient) {
        io.debug("HEEEElp")
        io.debug(message_to_client)
      },
    )

  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_builder.new()))

  let gen = random.int(0, 10_000_000_000)
  let subject = process.new_subject()
  let new_lobby = lobby.create_new_empty_lobby(gen)
  let assert Ok(my_lobby_orchestrator_actor) =
    actor.start(
      lobby_models.LobbyOrchestratorState(new_lobby, [], dict.new()),
      lobby_orchestrator.lobby_orchestrator_handle_message,
    )
  let assert Ok(_) =
    fn(req: Request(Connection)) -> Response(ResponseData) {
      case request.path_segments(req) {
        ["ws"] ->
          mist.websocket(
            request: req,
            on_init: on_init_with_orch(my_lobby_orchestrator_actor),
            on_close: fn(_state) { io.println("goodbye!") },
            handler: handle_ws_message,
          )
        _ -> not_found
      }
    }
    |> mist.new
    |> mist.port(3000)
    |> mist.start_http
  timer_execution_loop(my_lobby_orchestrator_actor, main_process_subject)
  // process.sleep_forever()
}

fn timer_execution_loop(my_lobby_orchestrator_actor, subject) {
  // loop_subject_receive_until(subject, 500, birl.utc_now())
  process.sleep(500)
  process.send(my_lobby_orchestrator_actor, lobby_models.LOGetResult)
  timer_execution_loop(my_lobby_orchestrator_actor, subject)
}

fn loop_subject_receive_until(
  subject: process.Subject(lobby_models.MessageToClient),
  milli_seconds: Int,
  start_time: birl.Time,
) {
  let message = process.receive(subject, milli_seconds)
  case message {
    Ok(message_to_client) -> {
      mist.send_text_frame(
        message_to_client.connection,
        message_to_client.message,
      )

      let from_start_to_now = birl.difference(birl.utc_now(), start_time)
      let order =
        duration.compare(
          from_start_to_now,
          duration.milli_seconds(milli_seconds),
        )

      case order {
        order.Lt -> {
          loop_subject_receive_until(
            subject,
            milli_seconds
              - duration.blur_to(from_start_to_now, duration.MilliSecond),
            start_time,
          )
          Nil
        }
        _ -> Nil
      }

      Nil
    }

    Error(_) -> Nil
  }
}
