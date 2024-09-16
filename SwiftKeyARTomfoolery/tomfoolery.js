// stoic quotes
const words = ["The best revenge is not to be like your enemy", "Be tolerant with others and strict with yourself", "The key is to keep company only with people who uplift you, whose presence calls forth your best", "The happiness of your life depends upon the quality of your thoughts", "The soul becomes dyed with the color of its thoughts", "The impediment to action advances action. What stands in the way becomes the way", "The best revenge is not to be like your enemy", "The best revenge is massive success"]

let gameStarted = false;
let progress = 0;

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

				// get the child elements of the target that are gltf-models
				let models = target.querySelectorAll('.player');

				models.forEach((model, i) => {
					model.object3D.position.x = i * 0.8;
					// set the position of the models to the position of the target
					const gltf = model.querySelector('a-gltf-model');
					const isPlayer = model.getAttribute('id') === 'player';
					const opacity = isPlayer ? 0.8 : 0.4;
					// make the model semi transparent
					let mesh = gltf.getObject3D('mesh');
					mesh.traverse((node) => {
						if (node.isMesh) {
							node.material.transparent = true;
							node.material.opacity = opacity
						}
					});
				});

				messageEl.innerHTML = "Click on the button when you're done placing the cars...";

				// use the button to finalize the cars' position.
				overlayBtn.style.display = 'block';
				overlayBtn.innerHTML = "Done placing car";
				session.removeEventListener('select', onsessionselect);
				element.setAttribute('visible', false);
				overlayBtn.addEventListener('click', function onfinishedplacing() {
					element.setAttribute('visible', false);
					overlayBtn.removeEventListener('click', onfinishedplacing);
					overlayBtn.style.display = 'none';
					gameStarted = true;
					startGame();
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
		if (gameStarted) {
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

AFRAME.registerComponent('ar-shadows', {
	// Swap an object's material to a transparent shadows-only material while
	// in AR mode. Intended for use with a ground plane.
	schema: {
		opacity: { default: 0.3 }
	},
	init: function() {
		// this.el.sceneEl.addEventListener('enter-vr', () => {
		this.wasVisible = this.el.getAttribute('visible');
		// if (this.el.sceneEl.is('ar-mode')) {
		this.savedMaterial = this.el.object3D.children[0].material;
		this.el.object3D.children[0].material = new THREE.ShadowMaterial();
		this.el.object3D.children[0].material.opacity = this.data.opacity;
		this.el.setAttribute('visible', true);
		// }
		// });
		// this.el.sceneEl.addEventListener('exit-vr', () => {
		// 	if (this.savedMaterial) {
		// 		this.el.object3D.children[0].material = this.savedMaterial;
		// 		this.savedMaterial = null;
		// 	}
		// 	if (!this.wasVisible) this.el.setAttribute('visible', false);
		// });
	}
});

function startGame() {
	let overlayMsg = document.getElementById('overlay-msg');
	overlayMsg.innerHTML = "Type the word you see.";

	let input = document.getElementById('input');

	changeWord();

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
	const randPozNeg = rand(0, 1) === 0 ? -1 : 1;
	wordEl.getAttribute('position').z = -randZ;
	wordEl.getAttribute('position').y = randY;
	wordEl.getAttribute('position').x = randX * randPozNeg;
	wordEl.object3D.lookAt(document.querySelector('[camera]').object3D.position);
}

function rand(min, max) {
	return Math.floor(Math.random() * (max - min + 1)) + min;
}

function updateProgress() {
	progress += 10;
	let player = document.getElementById('player');
	let playerPosition = player.getAttribute('position');
	let start = document.getElementById('target');
	let finish = document.getElementById('finish');
	let totalDistance = start.object3D.position.distanceTo(finish.object3D.position);
	let progressInMeters = (progress * totalDistance) / 100;
	let targetPosition = `${playerPosition.x} ${playerPosition.y} ${progressInMeters}`;

	player.setAttribute('animation', {
		property: 'position',
		to: targetPosition,
		dur: 1000,
		easing: 'easeInOutQuad'
	});
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
