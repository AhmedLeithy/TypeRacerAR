import actors/lobby.{type Lobby, type LobbyMsg, type LobbyState}
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/io
import gleam/otp/actor
import mist.{type WebsocketConnection}
import prng/random.{type Generator}
import prng/seed
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
    // player_uuid : Lobby reference
    id_gen: Generator(Int),
  )
}

// Handle messages
pub fn lobby_orchestrator_handle_message(
  lobby_orchestrator_msg: LobbyOrchestratorMsg,
  state: LobbyOrchestratorState,
) -> actor.Next(LobbyOrchestratorMsg, LobbyOrchestratorState) {
  case lobby_orchestrator_msg {
    LOJoinLobbyRequest(player_name, player_uuid, car_id, connection) -> {
      case player_uuid {
        "" -> {
          // create user id
          let #(random_int, updated_seed) =
            state.id_gen |> random.step(seed.random())
          let random_id = int.to_string(random_int)
          let player_uuid = player_name <> "_" <> random_id

          let new_state =
            add_waiting_user(
              player_uuid,
              player_name,
              car_id,
              connection,
              state,
            )

          // RETURN PLAYER ID 
          // process.send(client, player_uuid)
          actor.continue(new_state)
        }
        _ -> {
          let new_state =
            add_waiting_user(
              player_uuid,
              player_name,
              car_id,
              connection,
              state,
            )
          // Continue with new state
          actor.continue(new_state)
        }
      }
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
  // NOT HANDLED IF USER ALREADY IN GAME

  // create player obj
  let player = player.Player(player_name, player_uuid, car_id, conn)

  // add user to waiting list
  let new_waiting_user_list = [player, ..state.waiting_players]
  let new_state =
    LobbyOrchestratorState(..state, waiting_players: new_waiting_user_list)
  // CALL CHECK IF WE CAN START LOBBY
}
