// stoic quotes
let words = ["The best revenge is not to be like your enemy", "Be tolerant with others and strict with yourself", "The key is to keep company only with people who uplift you, whose presence calls forth your best", "The happiness of your life depends upon the quality of your thoughts", "The soul becomes dyed with the color of its thoughts", "The impediment to action advances action. What stands in the way becomes the way", "The best revenge is not to be like your enemy", "The best revenge is massive success"]

let donePlacing = false;
let progress = 0;
let player_id = null;
var ws;
let cars = ['ferrari_roma', 'chevrolet_camaro', 'audi_rs7', 'tesla_cybertruck', 'mazda_rx7', 'ferrari_br20'];

window.onload = function() {
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
						let msg = JSON.parse(event.data);
						if (msg.type === 'state') {
							let state = JSON.parse(msg.obj);
							player_id = state.player_uuid;
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
					});

					return;
					// simulate joining a game
					player_id = "10";
					let player_list = [
						{ id: player_id, car: 0, progress: 0.0 },
						{ id: 'player2', car: 1, progress: 0.0 },
						{ id: 'player3', car: 2, progress: 0.0 },
						{ id: 'player4', car: 3, progress: 0.0 },
						{ id: 'player5', car: 4, progress: 0.0 },
						{ id: 'player6', car: 5, progress: 0.0 }
					];
					addOrUpdatePlayers(player_list);

					// simulate players disconnecting
					setTimeout(() => {
						player_list = player_list.slice(0, 4);
						addOrUpdatePlayers(player_list);
					}, 4000);

					// simulate player progress update
					setTimeout(() => {
						player_list.forEach((player, i) => { player.progress = 10 * i });
						addOrUpdatePlayers(player_list);
					}, 8000);
					// startGame();
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
		let playerProgress = playerObj.progress;
		if (playerProgress === 100) {
			return;
		}
		let playerPosition = player.getAttribute('position');
		let start = target.getAttribute('position');
		let finish = document.getElementById('finish').getAttribute('position');
		let totalDistance = Math.abs(start.z - finish.z);
		let progressInMeters = (playerProgress * totalDistance) / 100;
		let targetPosition = `${playerPosition.x} ${playerPosition.y} ${progressInMeters}`;

		player.setAttribute('animation', {
			property: 'position',
			to: targetPosition,
			dur: 1000,
			easing: 'easeInOutQuad'
		});
	});

	let playersToAdd = player_list.filter((player) => !currentPlayerIds.includes(player.id));
	document.querySelector('#overlay-msg').innerHTML = `Players: ${playersToAdd.map(p => p.id).join(', ')}`;

	currentPlayers = target.querySelectorAll('.player');
	let lastPlayerPosition = currentPlayers.length > 0
		? currentPlayers[currentPlayers.length - 1].getAttribute('position').clone()
		: target.getAttribute('position').clone();

	playersToAdd.forEach((player) => {
		let newPlayer = document.createElement('a-entity');
		newPlayer.setAttribute('id', player.id);
		newPlayer.setAttribute('class', 'player');
		newPlayer.setAttribute('position', `${lastPlayerPosition.x + 0.8} 0 ${lastPlayerPosition.z}`);
		newPlayer.setAttribute('mesh-opacity', { opacity: 0.5 });
		lastPlayerPosition.x += 0.8;

		let gltf = document.createElement('a-gltf-model');
		gltf.setAttribute('src', `#${cars[player.car]}`);
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
	overlayMsg.innerHTML = "Type the word you see.";

	let input = document.getElementById('input');

	changeWord();

	if (window.location.href.includes("isdebug")) {
		setInterval(() => {
			updateProgress();
			changeWord();
		}, rand(3000, 5000));
	}

	input.addEventListener('input', function() {
		let wordEl = document.getElementById('word');
		let word = wordEl.getAttribute('value').toLowerCase();
		let inputVal = input.value;

		if (inputVal.toLowerCase() === word) {
			overlayMsg.innerHTML = "Correct!";
			input.style.display = 'none';
			input.value = '';

			updateProgress();
			changeWord();
		}
	});
}

function changeWord() {
	input.style.display = 'block';
	input.focus();

	let wordEl = document.getElementById('word');

	let randomWord = words[Math.floor(Math.random() * words.length)];
	wordEl.setAttribute('value', randomWord);

	let colors = ['blue', 'red', 'green', 'purple', 'orange', 'brown', 'black', 'white'];
	let randomColor = colors[Math.floor(Math.random() * colors.length)];
	wordEl.setAttribute('color', randomColor);

	const randZ = rand(3, 5);
	const randY = rand(1, 2);
	const randX = rand(0, 1);
	const randPozNeg = Math.random() < 0.5 ? -1 : 1;
	wordEl.getAttribute('position').z = -randZ;
	wordEl.getAttribute('position').y = randY;
	wordEl.getAttribute('position').x = randX * randPozNeg;
	wordEl.object3D.lookAt(document.querySelector('[camera]').object3D.position);
}

function rand(min, max) {
	return Math.floor(Math.random() * (max - min + 1)) + min;
}

function updateProgress() {
	if(progress >= 100) {
		return;
	}
	progress += 10;
	let wsMsg = {
		type: "progress",
		obj: JSON.stringify({progress: progress})
	};
	ws.send(JSON.stringify(wsMsg));
	// let player = document.getElementById('player');
	// let playerPosition = player.getAttribute('position');
	// let start = document.getElementById('target');
	// let finish = document.getElementById('finish');
	// let totalDistance = start.object3D.position.distanceTo(finish.object3D.position);
	// let progressInMeters = (progress * totalDistance) / 100;
	// let targetPosition = `${playerPosition.x} ${playerPosition.y} ${progressInMeters}`;
	//
	// player.setAttribute('animation', {
	// 	property: 'position',
	// 	to: targetPosition,
	// 	dur: 1000,
	// 	easing: 'easeInOutQuad'
	// });
}

AFRAME.registerComponent('car-select', {
	init: function() {
		const cars = this.el.querySelectorAll('a-gltf-model');
		const overlayBtn = document.getElementById('overlay-btn');
		overlayBtn.addEventListener('click', function() {
			overlayBtn.innerHTML = "Type the word you see.";
		});
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
	return new WebSocket('http://localhost:3000/ws');
}
