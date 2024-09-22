// stoic quotes
let words = []

let donePlacing = false;
let progress = 0;
let player_id = null;
let game_state = 'pending';
let start_time = null;
var ws;
let cars = ['ferrari_roma', 'chevrolet_camaro', 'audi_rs7', 'tesla_cybertruck', 'mazda_rx7', 'ferrari_br20'];
let username = localStorage.getItem('username');

window.onload = function() {
	if (!username && window.location.href.includes("game.html")) {
		username = prompt("Enter your username") || "Alpha";
		localStorage.setItem('username', username);
	}
	// check if we're in debug mode
	const isdebug = window.location.href.includes("isdebug");
	if (!isdebug) {
		return;
	}
	const scene = document.querySelector('a-scene');
	const target = scene.querySelector('#target');
	target.setAttribute('scale', '0.5 0.5 0.5');
	target.setAttribute('position', '0 0 -5');
	target.setAttribute('rotation', '0 180 0');
	target.setAttribute('visible', true);
	donePlacing = true;

	// get current car id
	const searchParams = new URLSearchParams(window.location.search);
	const car = searchParams.get('car');
	const carId = cars.indexOf(car);

	if (!ws || ws.readyState !== ws.OPEN) {
		ws = initWS();
	}

	// send join message
	ws.addEventListener('open', () => {
		console.log('opened connection!');
		let joinMsg = {
			type: 'join',
			obj: JSON.stringify({
				player_name: 'Alpha',
				player_uuid: '',
				car_id: carId
			})
		};
		ws.send(JSON.stringify(joinMsg));
	});
	ws.addEventListener('message', (event) => {
		console.log('received msg', event.data);
		let msg = JSON.parse(event.data);
		if (msg.type === 'state') {
			let state = msg.obj;
			player_id = state.player_uuid;
			if (!start_time && game_state === 'pending') {
				start_time = new Date(msg.obj.start_time);
				let countdown = setInterval(() => {
					let now = new Date();
					let timeDiff = start_time - now;
					if (timeDiff <= 0 || game_state === 'started') {
						clearInterval(countdown);
						return;
					}
					let seconds = Math.floor((timeDiff / 1000) % 60);
					let minutes = Math.floor((timeDiff / (1000 * 60)) % 60);

					document.getElementById('overlay-msg').innerHTML = `Hello, ${username}. Starting in ${minutes}m ${seconds}s`;
				}, 1000);
			}
			let player_list = state.player_progress.map((player) => {
				return {
					id: player.player_uuid,
					car: player.car_id,
					progress: player.progress,
					time_to_finish: player.play_time,
				};
			});
			addOrUpdatePlayers(player_list);
			return;
		}
		if (msg.type === 'start') {
			words = msg.obj;
			game_state = 'started';
			startGame();
			return;
		}
	});

	return;
}

AFRAME.registerComponent('hit-test', {
	init: function() {
		var messageEl = document.querySelector('#overlay-msg');

		this.xrHitTestSource = null;
		this.viewerSpace = null;
		this.refSpace = null;

		this.el.sceneEl.renderer.xr.addEventListener('sessionend', () => {
			this.viewerSpace = null;
			this.refSpace = null;
			this.xrHitTestSource = null;
		});
		this.el.sceneEl.renderer.xr.addEventListener('sessionstart', () => {
			messageEl.innerHTML = "Wait for a blue circle to appear and tap on the ground to set the car position. If it doesn't appear, try moving the camera around the room.";

			let session = this.el.sceneEl.renderer.xr.getSession();
			let element = this.el;
			let overlayBtn = document.getElementById('overlay-btn');
			let target = document.getElementById('target');
			let camera = document.querySelector('[camera]');

			session.addEventListener('select', function onsessionselect() {
				if (donePlacing) {
					return;
				}

				let target_pos = element.getAttribute('position');
				let camera_pos = camera.getAttribute('position');

				if (camera_pos.distanceTo(target_pos) > 2) {
					messageEl.innerHTML = "Too far away. Select a point closer to you.";
					return;
				}

				let current_camera_rotation = camera.getAttribute('rotation');
				target.setAttribute('rotation', { x: 0, y: current_camera_rotation.y - 180, z: 0 });
				target.setAttribute('position', target_pos);
				target.setAttribute('visible', true);

				messageEl.innerHTML = "Click on the button when you're done placing the cars...";

				// use the button to finalize the cars' position.
				overlayBtn.style.display = 'block';
				overlayBtn.innerHTML = "Done placing car";

				overlayBtn.addEventListener('click', function onfinishedplacing(evt) {
					evt.stopPropagation();
					messageEl.innerHTML = "Done placing cars! Waiting for other players...";
					element.setAttribute('visible', false);
					overlayBtn.removeEventListener('click', onfinishedplacing);
					overlayBtn.style.display = 'none';
					donePlacing = true;

					// get current car id
					const searchParams = new URLSearchParams(window.location.search);
					const car = searchParams.get('car');
					const carId = cars.indexOf(car);

					if (!ws || ws.readyState !== ws.OPEN) {
						ws = initWS();
					}

					// send join message
					ws.addEventListener('open', () => {
						console.log('opened connection!');
						let joinMsg = {
							type: 'join',
							obj: JSON.stringify({
								player_name: 'Alpha',
								player_uuid: '',
								car_id: carId
							})
						};
						ws.send(JSON.stringify(joinMsg));
					});
					ws.addEventListener('message', (event) => {
						console.log('received msg', event.data);
						let msg = JSON.parse(event.data);
						if (msg.type === 'state') {
							let state = msg.obj;
							player_id = state.player_uuid;
							if (!start_time && game_state === 'pending') {
								start_time = new Date(msg.obj.start_time);
								let countdown = setInterval(() => {
									let now = new Date();
									let timeDiff = start_time - now;
									if (timeDiff <= 0 || game_state === 'started') {
										clearInterval(countdown);
										return;
									}
									let seconds = Math.floor((timeDiff / 1000) % 60);
									let minutes = Math.floor((timeDiff / (1000 * 60)) % 60);

									document.getElementById('overlay-msg').innerHTML = `Hello, ${username}. Starting in ${minutes}m ${seconds}s`;
								}, 1000);
							}
							let player_list = state.player_progress.map((player) => {
								return {
									id: player.player_uuid,
									car: player.car_id,
									progress: player.progress
								};
							});
							addOrUpdatePlayers(player_list);
							return;
						}
						if (msg.type === 'start') {
							words = msg.obj;
							game_state = 'started';
							startGame();
							return;
						}
					});

					return;
				});
			});

			session.requestReferenceSpace('viewer').then((space) => {
				this.viewerSpace = space;
				session.requestHitTestSource({ space: this.viewerSpace })
					.then((hitTestSource) => {
						this.xrHitTestSource = hitTestSource;
					});
			});

			session.requestReferenceSpace('local-floor').then((space) => {
				this.refSpace = space;
			});
		});
	},
	tick: function() {
		if (donePlacing) {
			return;
		}
		if (this.el.sceneEl.is('ar-mode')) {
			if (!this.viewerSpace) return;

			let frame = this.el.sceneEl.frame;
			let xrViewerPose = frame.getViewerPose(this.refSpace);

			if (this.xrHitTestSource && xrViewerPose) {
				let hitTestResults = frame.getHitTestResults(this.xrHitTestSource);
				if (hitTestResults.length > 0) {
					let pose = hitTestResults[0].getPose(this.refSpace);

					let inputMat = new THREE.Matrix4();
					inputMat.fromArray(pose.transform.matrix);

					let position = new THREE.Vector3();
					position.setFromMatrixPosition(inputMat);
					this.el.setAttribute('position', position);
				}
			}
		}
	}
});

function addOrUpdatePlayers(player_list) {
	let target = document.getElementById('target');

	// current player not added yet
	let currentPlayerCarEntity = target.querySelector('#current_player');
	if (currentPlayerCarEntity) {
		const searchParams = new URLSearchParams(window.location.search);
		const car = searchParams.get('car');

		currentPlayerCarEntity.setAttribute('id', player_id);
		let currentPlayerCar = document.createElement('a-gltf-model');
		currentPlayerCar.setAttribute('scale', '0.3 0.3 0.3');
		currentPlayerCar.setAttribute('src', `#${car}`);
		currentPlayerCarEntity.appendChild(currentPlayerCar);
	}

	let currentPlayers = target.querySelectorAll('.player');
	let currentPlayerIds = Array.from(currentPlayers).map((player) => player.getAttribute('id'));
	let playersToRemove = Array.from(currentPlayers).filter((player) => !player_list.map(p => p.id).includes(player.getAttribute('id')));
	playersToRemove.forEach((player) => {
		// show a disconnect logo above the player
		const disconnectImg = document.createElement('a-image');
		disconnectImg.setAttribute('src', '#disconnect');
		disconnectImg.setAttribute('scale', '0.5 0.5 0.5');
		disconnectImg.setAttribute('rotation', '90 0 0');
		disconnectImg.setAttribute('position', '0 1 0');
		player.appendChild(disconnectImg);

		// remove the player after 2 seconds
		setTimeout(() => {
			player.parentNode.removeChild(player);
		}, 2000);
	});

	// update progress
	currentPlayers = target.querySelectorAll('.player');
	currentPlayers.forEach((player) => {
		let playerObj = player_list.find((p) => p.id === player.getAttribute('id'));
		if (player.getAttribute('progress') == playerObj.progress) {
			return;
		}
		player.setAttribute('progress', playerObj.progress);

		if (playerObj.progress >= 100) {
			let starModel = document.createElement('a-gltf-model');
			starModel.setAttribute('src', '#star');
			starModel.setAttribute('scale', '0.3 0.3 0.3');
			starModel.setAttribute('position', '0 2 0');
			starModel.setAttribute('animation', {
				property: 'rotation',
				to: '0 360 0',
				dur: 1000,
				easing: 'easeInOutQuad',
				loop: true
			});
			player.appendChild(starModel);
			player.setAttribute('timeToFinish', playerObj.time_to_finish);
		}

		let playerPosition = player.getAttribute('position');
		let start = target.querySelector('#start').getAttribute('position');
		let finish = document.getElementById('finish').getAttribute('position');
		if (start.z >= finish.z) {
			return;
		}
		let totalDistance = finish.z - start.z;
		let progressInMeters = (playerObj.progress * totalDistance) / 100.0;
		progressInMeters = Math.min(progressInMeters, finish.z - 2);
		let targetPosition = `${playerPosition.x} ${playerPosition.y} ${progressInMeters}`;
		console.log('target pos', targetPosition);

		player.setAttribute('animation', {
			property: 'position',
			to: targetPosition,
			dur: 1000,
			easing: 'easeInOutQuad'
		});
	});

	let playersToAdd = player_list.filter((player) => !currentPlayerIds.includes(player.id));

	currentPlayers = target.querySelectorAll('.player');
	let lastPlayerPosition = currentPlayers.length > 0
		? currentPlayers[currentPlayers.length - 1].getAttribute('position').clone()
		: target.getAttribute('position').clone();

	playersToAdd.forEach((player) => {
		let newPlayer = document.createElement('a-entity');
		newPlayer.setAttribute('id', player.id);
		newPlayer.setAttribute('class', 'player');
		newPlayer.setAttribute('position', `${lastPlayerPosition.x + 0.9} 0 ${lastPlayerPosition.z}`);
		newPlayer.setAttribute('mesh-opacity', { opacity: 0.5 });
		lastPlayerPosition.x += 0.9;

		let gltf = document.createElement('a-gltf-model');
		gltf.setAttribute('src', `#${cars[player.car]}`);
		gltf.setAttribute('shadow', "");
		gltf.setAttribute('scale', '0.3 0.3 0.3');

		newPlayer.appendChild(gltf);
		target.appendChild(newPlayer);
	});
}

AFRAME.registerComponent('ar-shadows', {
	// Swap an object's material to a transparent shadows-only material while
	// in AR mode. Intended for use with a ground plane.
	schema: {
		opacity: { default: 0.3 }
	},
	init: function() {
		this.wasVisible = this.el.getAttribute('visible');
		this.savedMaterial = this.el.object3D.children[0].material;
		this.el.object3D.children[0].material = new THREE.ShadowMaterial();
		this.el.object3D.children[0].material.opacity = this.data.opacity;
		this.el.setAttribute('visible', true);
	}
});

function startGame() {
	let overlayMsg = document.getElementById('overlay-msg');
	overlayMsg.innerHTML = "Game started. Type the word you see.";

	let input = document.getElementById('input');

	changeWord();

	if (window.location.href.includes("isdebug")) {
		const interval = setInterval(() => {
			if (progress >= 100) {
				clearInterval(interval);
				return;
			}
			updateProgress();
			changeWord();
		}, rand(3000, 4000));
	}

	input.addEventListener('input', function() {
		let wordEl = document.getElementById('word');
		let word = wordEl.getAttribute('value').toLowerCase().trim();
		let inputVal = input.value;

		if (inputVal.toLowerCase().trim() === word) {
			overlayMsg.innerHTML = "Correct!";
			input.style.display = 'none';
			input.value = '';

			updateProgress();
			changeWord();
		}
	});
}

function changeWord() {
	let wordEl = document.getElementById('word');
	if (progress >= 100) {
		wordEl.setAttribute('visible', false);
		return;
	}
	let input = document.querySelector('#input');
	input.style.display = 'block';
	input.focus();

	let word = words[0];
	wordEl.setAttribute('value', word);

	let colors = ['blue', 'red', 'green', 'orange', 'white'];
	let randomColor = colors[Math.floor(Math.random() * colors.length)];
	wordEl.setAttribute('color', randomColor);

	let target = new THREE.Vector3();
	document.getElementById('finish').object3D.getWorldPosition(target);
	wordEl.setAttribute('position', `${target.x} ${target.y + 3} ${target.z}`);
	wordEl.object3D.lookAt(document.querySelector('[camera]').object3D.position);

	words = words.slice(1);
}

function rand(min, max) {
	return Math.floor(Math.random() * (max - min + 1)) + min;
}

function updateProgress() {
	progress += 10;
	if (progress >= 100) {
		let timeTaken = new Date() - start_time;
		let timeTakenInSeconds = Math.floor( (timeTaken / 1000) % 60);
		let timeTakenInMinutes = Math.floor( (timeTaken / (1000 * 60)) % 60);
		document.querySelector('#input').style.display = 'none';
		document.querySelector('#overlay-msg').innerHTML = `Finished in ${timeTakenInMinutes}m ${timeTakenInSeconds}s`;
		document.querySelector('#overlay-btn').style.display = 'block';
		document.querySelector('#overlay-btn').innerHTML = "Play again";
		document.querySelector('#overlay-btn').addEventListener('click', function() {
			window.open('index.html', '_self');
		});
	}
	let wsMsg = {
		type: "progress",
		obj: JSON.stringify({ progress: progress })
	};
	ws.send(JSON.stringify(wsMsg));
}

AFRAME.registerComponent('car-select', {
	init: function() {
		const cars = this.el.querySelectorAll('a-gltf-model');
		const textEl = this.el.querySelector('#text_select');
		const carNameEl = this.el.querySelector('#car_name');
		const play_triangle = textEl.querySelector('a-triangle');

		cars.forEach((car) => {
			car.addEventListener('click', function(evt) {
				let selectedCar = evt.target;
				let selectedCarId = selectedCar.getAttribute('src');
				carNameEl.setAttribute('value', selectedCarId.replace('#', '').replace('_', ' '));
				play_triangle.setAttribute('visible', true);

				// attatch a highlight to the selected car
				const highlight = document.getElementById('highlight');
				highlight.setAttribute('position', selectedCar.getAttribute('position'));
				highlight.setAttribute('visible', true);

				// change the text to the selected car
				textEl.setAttribute('value', 'look here to start the game!');
				textEl.setAttribute('color', 'green');

				// animate the camera to look at the selected car
				const camera = document.querySelector('[camera]')
				camera.object3D.lookAt(selectedCar.object3D.position);

				textEl.addEventListener('click', function() {
					window.open('game.html?car=' + selectedCarId.replace('#', ''), '_self');
				});
			});
		});

	}
});

AFRAME.registerComponent('mesh-opacity', {
	schema: {
		opacity: { default: 0.5 }
	},
	init: function() {
		this.el.addEventListener('model-loaded', () => {
			this.el.object3D.traverse((node) => {
				if (node.material) {
					node.material.transparent = true;
					node.material.opacity = this.data.opacity;
				}
			});
		});
	}
});

function initWS() {
	return new WebSocket('https://typeracerarbackend.azurewebsites.net/ws');
}
