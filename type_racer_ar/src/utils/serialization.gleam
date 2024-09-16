import actors/lobby.{type LobbyMsg, LGetResult, LMovePlayer}
import decode
import gleam/dict
import gleam/dynamic.{type Dynamic, field, float, int, string}
import gleam/io
import gleam/json.{type DecodeError, UnexpectedSequence}

pub type ClientMessage {
  ClientMessage(type_: String, obj: String)
}

pub type ClientMessageCommand {
  JoinLobbyRequest(player_name: String, player_uuid: String, car_id: Int)
  MovePlayer(progress: Float)
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

  let move_player_decoder =
    dynamic.decode1(MovePlayer, field("progress", of: float))

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
        "progress" ->
          json.decode(
            deserialized_client_message.obj,
            using: move_player_decoder,
          )
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
