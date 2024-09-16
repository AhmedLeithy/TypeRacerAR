import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/otp/actor
import records/game.{type GameStatus}

pub type Lobby {
  Lobby(lobby_id: String, actor: process.Subject(LobbyMsg))
  // active player ids?
}

// Define a message type
pub type LobbyMsg {
  LMovePlayer(String, Float)
  LGetResult(reply_with: Subject(LobbyState))
}

// Define the actor's state
pub type LobbyState {
  LobbyState(player_progress: dict.Dict(String, Float), GameStatus)
}

// Handle messages
pub fn lobby_handle_message(
  msg: LobbyMsg,
  state: LobbyState,
) -> actor.Next(LobbyMsg, LobbyState) {
  case msg {
    LMovePlayer(player_name, new_progress) -> {
      let new_state_dict =
        state.player_progress
        |> dict.insert(player_name, new_progress)

      let new_state = LobbyState(..state, player_progress: new_state_dict)
      io.debug(new_state)
      actor.continue(new_state)
    }

    LGetResult(client) -> {
      process.send(client, state)
      actor.continue(state)
    }
  }
}

// 1 - Send update when lobby is joined (when pending) 
// 2 - Send update when other players join (when pending) ( same as 1)
// 3 -  Send update when game started + Words
// 4 - Send Periodic Update with game status
// 5 - Send terminal Status


pub fn send_update {

}