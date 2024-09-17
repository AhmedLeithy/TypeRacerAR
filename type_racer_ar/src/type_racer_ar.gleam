import actors/lobby.{create_new_empty_lobby}
import actors/lobby_orchestrator.{lobby_orchestrator_handle_message}
import birl
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
import models/lobby_models
import prng/random
import prng/seed

import gleam/json
import socket/socket_handler.{SocketState, handle_ws_message}
import utils/serialization

pub fn main() {
  io.debug(serialization.serialize("test", json.string("a")))

  // These values are for the Websocket process initialized below
  let selector = process.new_selector()
  let gen = random.int(0, 10_000_000_000)

  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_builder.new()))

  // let assert Ok(future_time) = birl.now_with_offset("12:00")

  let new_lobby = create_new_empty_lobby(gen)
  let assert Ok(my_lobby_orchestrator_actor) =
    actor.start(
      lobby_models.LobbyOrchestratorState(new_lobby, [], dict.new()),
      lobby_orchestrator_handle_message,
    )

  // let assert Ok(my_lobby_orchestrator_actor) =
  //   actor.start(LobbyState(dict.new()), lobby_orchestrator_handle_message)

  let init_state = SocketState(my_lobby_orchestrator_actor, "", "", gen)
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

  recursively_timer(my_lobby_orchestrator_actor)
  // process.sleep_forever()
}

fn recursively_timer(my_lobby_orchestrator_actor) {
  process.sleep(500)
  process.send(my_lobby_orchestrator_actor, lobby_models.LOGetResult)
  recursively_timer(my_lobby_orchestrator_actor)
}
