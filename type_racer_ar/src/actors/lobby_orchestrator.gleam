import actors/lobby.{type Lobby, type LobbyMsg, type LobbyState}
import birl
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/otp/actor
import mist.{type WebsocketConnection}
import records/player.{type Player}

// Define a message type
pub type LobbyOrchestratorMsg {
  LOJoinLobbyRequest(
    player_name: String,
    player_uuid: String,
    car_id: Int,
    connection: mist.WebsocketConnection,
    // reply_with: Subject(String),
  )
  LOMovePlayer(player_uuid: String, String)
  LOGetResult(reply_with: Subject(LobbyOrchestratorState))
}

// Define the actor's state
pub type LobbyOrchestratorState {
  LobbyOrchestratorState(
    waiting_players: List(Player),
    active_lobbies: List(Lobby),
    player_to_lobby: dict.Dict(String, Lobby),
    time_waiting: birl.Time,
  )
}

// Handle messages
pub fn lobby_orchestrator_handle_message(
  lobby_orchestrator_msg: LobbyOrchestratorMsg,
  state: LobbyOrchestratorState,
) -> actor.Next(LobbyOrchestratorMsg, LobbyOrchestratorState) {
  case lobby_orchestrator_msg {
    LOJoinLobbyRequest(player_name, player_uuid, car_id, connection) -> {
      let new_state =
        add_waiting_user(player_uuid, player_name, car_id, connection, state)
      io.debug(new_state)
      actor.continue(new_state)
    }
    LOMovePlayer(player_uuid, new_progress) -> {
      // TODO
      let lobby =
        state.player_to_lobby
        |> dict.get(player_uuid)

      actor.continue(state)
    }
    LOGetResult(client) -> {
      process.send(client, state)
      actor.continue(state)
    }
  }
}

fn add_waiting_user(
  player_uuid: String,
  player_name: String,
  car_id: Int,
  conn: WebsocketConnection,
  state: LobbyOrchestratorState,
) -> LobbyOrchestratorState {
  // check if user already in list
  let player_already_waiting =
    state.waiting_players
    |> list.count(fn(p) { p.player_uuid == player_uuid })

  case player_already_waiting {
    0 -> {
      let player = player.Player(player_name, player_uuid, car_id, conn)

      // add user to waiting list
      let new_waiting_user_list = [player, ..state.waiting_players]
      let new_state =
        LobbyOrchestratorState(..state, waiting_players: new_waiting_user_list)
    }
    _ -> {
      io.debug("player already waiting")
      state
    }
  }
  // CALL CHECK IF WE CAN START LOBBY
  // should_start_lobby(state)
}

fn should_start_lobby(state) -> LobbyOrchestratorState {
  state
  // if player count -> start lobby
  // if time passed -> start lobby

  // 
}

fn start_lobby(state) -> LobbyOrchestratorState {
  todo
}
