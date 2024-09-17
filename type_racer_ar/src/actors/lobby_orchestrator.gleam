import birl
import birl/duration.{Duration}
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/option
import gleam/otp/actor
import mist.{type WebsocketConnection}
import models/lobby_models
import records/player.{type Player}

// Handle messages
pub fn lobby_orchestrator_handle_message(
  lobby_orchestrator_msg: lobby_models.LobbyOrchestratorMsg,
  state: lobby_models.LobbyOrchestratorState,
) -> actor.Next(
  lobby_models.LobbyOrchestratorMsg,
  lobby_models.LobbyOrchestratorState,
) {
  case lobby_orchestrator_msg {
    lobby_models.LOJoinLobbyRequest(
      player_name,
      player_uuid,
      car_id,
      connection,
    ) -> {
      let new_state =
        add_waiting_user(player_uuid, player_name, car_id, connection, state)
      io.debug(new_state)
      actor.continue(new_state)
      // Ready includes status + {pllayer uuid}
    }
    lobby_models.LOMovePlayer(player_uuid, new_progress) -> {
      // TODO
      let lobby =
        state.player_to_lobby
        |> dict.get(player_uuid)

      actor.continue(state)
    }
    lobby_models.LOGetResult -> {
      send_lobby_status_request(state.waiting_lobby)
      list.each(state.active_lobbies, fn(lby) { send_lobby_status_request(lby) })
      actor.continue(state)
    }
  }
}

fn send_lobby_status_request(lobby: lobby_models.Lobby) {
  process.send(lobby.actor, lobby_models.LGetResult)
  todo
}

fn add_waiting_user(
  player_uuid: String,
  player_name: String,
  car_id: Int,
  conn: WebsocketConnection,
  state: lobby_models.LobbyOrchestratorState,
) -> lobby_models.LobbyOrchestratorState {
  todo
  // CALL CHECK IF WE CAN START LOBBY
  // should_start_lobby(state)

  let player =
    player.Player(player_name, player_uuid, car_id, conn, option.None)
  state
  // try add player to waiting lobby
}

fn should_start_lobby(state) -> lobby_models.LobbyOrchestratorState {
  state
  // if player count -> start lobby
  // if time passed -> start lobby

  // 
}

fn start_lobby(state) -> lobby_models.LobbyOrchestratorState {
  todo
}
