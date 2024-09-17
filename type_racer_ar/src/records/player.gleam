import birl/duration.{type Duration}
import gleam/option.{type Option}
import mist.{type WebsocketConnection}

// Define the actor's state
pub type Player {
  Player(
    player_name: String,
    player_uuid: String,
    car_id: Int,
    connection: WebsocketConnection,
    play_time: Option(Duration),
  )
}

pub type PlayerResponse {
  PlayerResponse(
    player_name: String,
    player_uuid: String,
    car_id: Int,
    connection: WebsocketConnection,
  )
}
