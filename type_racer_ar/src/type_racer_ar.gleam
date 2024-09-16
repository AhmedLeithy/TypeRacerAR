import actors/lobby_orchestrator.{
  LobbyOrchestratorState, lobby_orchestrator_handle_message,
}
import gleam/bit_array
import gleam/bytes_builder
import gleam/dict
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/iterator
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string
import mist.{type Connection, type ResponseData}
import prng/random
import prng/seed

import socket/socket_handler.{SocketState, handle_ws_message}

pub fn main() {
  // These values are for the Websocket process initialized below
  let selector = process.new_selector()
  let gen = random.int(0, 10_000_000_000)

  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_builder.new()))

  let assert Ok(my_lobby_orchestrator_actor) =
    actor.start(
      LobbyOrchestratorState([], [], dict.new(), gen),
      lobby_orchestrator_handle_message,
    )

  // let assert Ok(my_lobby_orchestrator_actor) =
  //   actor.start(LobbyState(dict.new()), lobby_orchestrator_handle_message)

  let init_state = SocketState(my_lobby_orchestrator_actor, "", "")
  let assert Ok(_) =
    fn(req: Request(Connection)) -> Response(ResponseData) {
      case request.path_segments(req) {
        ["ws"] ->
          mist.websocket(
            request: req,
            on_init: fn(_conn) { #(init_state, Some(selector)) },
            on_close: fn(_state) { io.println("goodbye!") },
            handler: handle_ws_message,
          )
        _ -> not_found
      }
    }
    |> mist.new
    |> mist.port(3000)
    |> mist.start_http

  process.sleep_forever()
}
