import birl/duration
import decode
import gleam/dict
import gleam/dynamic.{type Dynamic, field, float, int, string}
import gleam/int
import gleam/io
import gleam/json.{type DecodeError, UnexpectedSequence, object}
import gleam/list
import gleam/option
import models/lobby_models
import records/game

pub type ClientMessage {
  ClientMessage(type_: String, obj: String)
}

pub type ClientMessageCommand {
  JoinLobbyRequest(player_name: String, player_uuid: String, car_id: Int)
  MovePlayer(progress: Float)
}

pub type MovePlayerIntTemp {
  MovePlayerIntTemp(progress: Int)
}

pub fn decode_message(
  json_string: String,
) -> Result(ClientMessageCommand, DecodeError) {
  let message_decoder =
    dynamic.decode2(
      ClientMessage,
      field("type", of: string),
      field("obj", of: string),
    )

  let join_lobby_decoder =
    dynamic.decode3(
      JoinLobbyRequest,
      field("player_name", of: string),
      field("player_uuid", of: string),
      field("car_id", of: int),
    )

  let move_player_float_decoder =
    dynamic.decode1(MovePlayer, field("progress", of: float))
  let move_player_int_decoder =
    dynamic.decode1(MovePlayerIntTemp, field("progress", of: int))

  let client_message = json.decode(from: json_string, using: message_decoder)
  io.debug(client_message)

  case client_message {
    Ok(deserialized_client_message) -> {
      case deserialized_client_message.type_ {
        "join" ->
          json.decode(
            deserialized_client_message.obj,
            using: join_lobby_decoder,
          )
        "progress" -> {
          case
            json.decode(
              deserialized_client_message.obj,
              using: move_player_float_decoder,
            )
          {
            Ok(res) -> Ok(res)
            Error(_) -> {
              let move_player_int =
                json.decode(
                  deserialized_client_message.obj,
                  using: move_player_int_decoder,
                )
              case move_player_int {
                Ok(int_res) ->
                  Ok(MovePlayer(progress: int.to_float(int_res.progress)))
                Error(e) -> Error(e)
              }
            }
          }
        }
        _ -> Error(UnexpectedSequence("unexpected sequence"))
      }
    }
    Error(error) -> {
      io.debug("invalid input")
      Error(error)
    }
  }
}

pub fn dict_to_string(dict: dict.Dict(String, String)) -> String {
  let entries =
    dict.fold(dict, "", fn(acc, key, value) {
      let entry = "\"" <> key <> "\" : \"" <> value <> "\""
      io.debug(entry)
      case acc {
        "" -> entry
        _ -> acc <> ", " <> entry
      }
    })
  let json_obj = "{ " <> entries <> " }"

  json_obj
}

pub fn serialize(type_string: String, json: json.Json) -> String {
  let obj_to_serialize =
    object([#("type", json.string(type_string)), #("obj", json)])
  json.to_string(obj_to_serialize)
}

pub fn seriailize_game_state(
  lobby_state: lobby_models.LobbyState,
  player_id: String,
) -> String {
  let state_obj =
    object([
      #("player_uuid", json.string(player_id)),
      #("status", json.string(gamestatus_to_string(lobby_state.status))),
      #("player_progress", serialize_players(lobby_state.player_progress)),
    ])
  serialize("state", state_obj)
}

pub fn serialize_players(
  player_dict: dict.Dict(String, lobby_models.Player),
) -> json.Json {
  player_dict
  |> dict.values()
  |> list.map(fn(player) { serialize_player(player) })
  |> json.array(of: fn(a) { a })
}

pub fn serialize_player(player: lobby_models.Player) -> json.Json {
  case player.play_time {
    option.Some(duration) -> {
      object([
        #("player_uuid", json.string(player.player_uuid)),
        #("player_name", json.string(player.player_name)),
        #("car_id", json.int(player.car_id)),
        #("progress", json.float(player.progress)),
        #(
          "play_time",
          json.int(duration.blur_to(duration, duration.MilliSecond)),
        ),
      ])
    }
    option.None -> {
      object([
        #("player_uuid", json.string(player.player_uuid)),
        #("player_name", json.string(player.player_name)),
        #("car_id", json.int(player.car_id)),
        #("progress", json.float(player.progress)),
        #("play_time", json.float(0.0)),
      ])
    }
  }
}

pub fn gamestatus_to_string(game_status: game.GameStatus) -> String {
  case game_status {
    game.Pending -> "pending"
    game.Running -> "running"
    game.Finished -> "finished"
  }
}
