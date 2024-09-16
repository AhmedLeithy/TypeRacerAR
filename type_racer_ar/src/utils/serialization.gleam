import actors/lobby.{type LobbyMsg, LGetResult, LMovePlayer}
import decode
import gleam/dict
import gleam/dynamic.{type DecodeError, type Dynamic, field, int, string}
import gleam/io
import gleam/json

pub type ClientMessage {
  ClientMessage(type_: String, obj: String)
}

pub type ClientMessageCommand {
  JoinLobbyRequest(player_name: String, player_uuid: String, car_id: Int)
  MovePlayer(player_uuid: String, progress: Float)
}

pub fn decode_message(
  json_string: String,
) -> Result(ClientMessageCommand, List(DecodeError)) {
  io.debug(json_string)

  let decoded_result =
    json.decode(json_string, dynamic.dict(dynamic.string, dynamic.string))
  case decoded_result {
    Ok(dynamic_value) -> {
      let moveplayer_decoder =
        decode.into({
          use x <- decode.parameter
          use y <- decode.parameter
          MovePlayer(x, y)
        })
        |> decode.field("player_id", decode.string)
        |> decode.field("player_pos", decode.float)

      let updatescore_decoder =
        decode.into({
          use score <- decode.parameter
          // UpdateScore(score)
          MovePlayer("b", 1.0)
        })
        |> decode.field("score", decode.string)

      let decoder =
        decode.at(["type"], decode.string)
        |> decode.then(fn(tag) {
          case tag {
            "move" -> moveplayer_decoder
            "score" -> updatescore_decoder
            _ -> decode.fail("Unknown type")
          }
        })
      io.debug(dynamic_value)
      let dynamic = dynamic.from(dynamic_value)
      decoder
      |> decode.from(dynamic)
    }
    Error(decode_error) -> {
      io.debug(decode_error)
      Error([])
    }
  }
  // case json.decode(json_string, json.object) {
  //   Ok(json.Object(fields)) ->
  //     case field("action", fields) {
  //       Ok(json.String("move")) -> {
  //         let x = field("x", fields) |> json.as_int |> unwrap_or(0)
  //         let y = field("y", fields) |> json.as_int |> unwrap_or(0)
  //         Ok(MovePlayer(x, y))
  //       }
  //       Ok(json.String("score")) -> {
  //         let score = field("score", fields) |> json.as_int |> unwrap_or(0)
  //         Ok(UpdateScore(score))
  //       }
  //       _ -> Error("Unknown action")
  //     }
  //   _ -> Error("Invalid JSON")
  // }
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
