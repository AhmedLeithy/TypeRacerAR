import birl
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import mist
import records/game
import records/player.{type Player}

pub type Lobby {
  Lobby(lobby_id: String, actor: process.Subject(LobbyMsg))
  // active player ids?
}

// Define a message type
pub type LobbyMsg {
  LMovePlayer(String, Float)
  LGetResult
  LAddPlayer(player.Player, client: Subject(LobbyAddPlayerResult))
}

// Define the actor's state
pub type LobbyState {
  LobbyState(
    status: game.GameStatus,
    start_waiting_time: Option(birl.Time),
    start_time: Option(birl.Time),
    player_progress: dict.Dict(String, Player),
  )
}

pub type LobbyAddPlayerResult {
  Success
  AlreadyAdded
  AddedWillStart
  LobbyFull
  AlreadyStarted
}

// Define a message type
pub type LobbyOrchestratorMsg {
  LOJoinLobbyRequest(
    player_name: String,
    player_uuid: String,
    car_id: Int,
    connection: mist.WebsocketConnection,
  )
  LOMovePlayer(player_uuid: String, String)
  LOGetResult
}

// Define the actor's state
pub type LobbyOrchestratorState {
  LobbyOrchestratorState(
    waiting_lobby: Lobby,
    active_lobbies: List(Lobby),
    player_to_lobby: dict.Dict(String, Lobby),
    time_waiting: birl.Time,
  )
}
