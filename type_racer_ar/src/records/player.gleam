import mist.{type WebsocketConnection}

// Define the actor's state
pub type Player {
  Player(
    player_name: String,
    player_uuid: String,
    car_id: Int,
    connection: WebsocketConnection,
  )
}
