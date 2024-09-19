# TypeRacerAR

## Frontend

### Running

1. Install node
2. Install http-server `npm i -g http-server`
3. In the front end folder, run `http-server --ssl -c-1`
4. It should show you the url of the server, visit that from your phone (make sure to use https not http)

### Developing

Don't

## Backend

TODO

1. install gleam, erlang and rebar3.
2. navigate to gleam directory and run `gleam run`

### Docker

1. docker build  "C:\repo\TypeRacerAR\type_racer_ar" -t type_racer_ar_image
2. docker login typeraceracr.azurecr.io
3. docker tag  type_racer_ar_image typeraceracr.azurecr.io/type_racer
4. docker push typeraceracr.azurecr.io/type_racer

Client Requests

Join
```json
{
  "type" : "join",
  "obj" : "{\"player_name\":\"Alpha\",\"player_uuid\":\"\",\"car_id\":1}"
}
```

Progress
```json
{
  "type" : "progress",
  "obj" : "{\"progress\":1.1}"
}
```

Server Responses

Update State Message (When joining lobby, when waiting, when game is running and at termination)
```json
{
  "type": "state",
  "obj": {
    "player_uuid": "Alpha_3526552856",
    "status": "finished",
    "start_time" : DURATION, //TODO. THIS IS TO ALLOW THE CLIENT TO CREATE A COUNTDOWN TO SESSION START
    "player_progress": [
      {
        "player_uuid": "Alpha_3526552856",
        "player_name": "Alpha",
        "car_id": 1,
        "progress": 100,
        "play_time": 11
      },
      {
        "player_uuid": "Beta_3906748707",
        "player_name": "Beta",
        "car_id": 1,
        "progress": 100,
        "play_time": 27
      }
    ]
  }
}
```
On Game Start
```json
{
  "type": "start",
  "obj": [
    "The goal of life is living in agreement with nature.",
    "Don't explain your philosophy. Embody it.",
    "The more we value things outside our control, the less control we have.",
    "Circumstances don't make the man, they only reveal him to himself.",
    "If anyone tells you that a certain person speaks ill of you, do not make excuses about what is said of you but answer, 'He was ignorant of my other faults, else he would not have mentioned these alone.'",
    "It is the power of the mind to be unconquerable.",
    "To be even-minded is the greatest virtue.",
    "The best revenge is not to be like your enemy.",
    "First say to yourself what you would be; and then do what you have to do.",
    "He is a wise man who does not grieve for the things which he has not, but rejoices for those which he has."
  ]
}
```
