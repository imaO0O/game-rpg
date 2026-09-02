using System;
using Game.Interaction;
using UnityEngine;
using UnityEngine.InputSystem;

namespace Game.Player
{
    /// <summary>
    /// Контроллер от первого лица.
    ///
    /// Всё, что нужно для игры: ходьба, обзор, покачивание камеры при шаге.
    /// Ни прыжка, ни приседания, ни боя — опасность здесь в атмосфере,
    /// а не в противнике.
    ///
    /// Весь ввод игрока живёт тут: фонарь и взаимодействие ничего не знают
    /// про кнопки, контроллер сам зовёт их методы.
    /// </summary>
    [RequireComponent(typeof(CharacterController))]
    public sealed class FirstPersonController : MonoBehaviour
    {
        /// <summary>
        /// Прижимающая скорость на земле. На нуле CharacterController теряет
        /// контакт с полом на первом же стыке половиц и начинает дёргаться.
        /// </summary>
        private const float GroundStick = -2f;

        /// <summary>Ниже этого объект считается стоящим на месте.</summary>
        private const float MovingThreshold = 0.1f;

        [Header("Узлы")]
        [SerializeField] private Transform _head;
        [SerializeField] private Flashlight _flashlight;
        [SerializeField] private Interactor _interactor;

        [Header("Движение")]
        [SerializeField] private float _walkSpeed = 2.2f;
        [SerializeField] private float _runSpeed = 4f;

        [Header("Обзор")]
        [Tooltip("Градусов на пиксель движения мыши.")]
        [SerializeField] private float _mouseSensitivity = 0.12f;

        [Tooltip("Градусов в секунду при полностью отклонённом стике.")]
        [SerializeField] private float _stickSensitivity = 140f;

        [Tooltip("Насколько можно задрать и опустить голову, в градусах.")]
        [SerializeField] private float _pitchLimit = 80f;

        [Header("Покачивание")]
        [SerializeField] private float _bobAmount = 0.035f;
        [SerializeField] private float _bobSpeed = 9f;

        private GameControls _controls;
        private CharacterController _body;
        private HeadBob _bob;

        private Vector3 _headBasePosition;
        private float _pitch;
        private float _verticalVelocity;

        /// <summary>Нога коснулась пола. Отсюда берут момент звука шага.</summary>
        public event Action StepTaken;

        public bool IsRunning { get; private set; }

        private void Awake()
        {
            _body = GetComponent<CharacterController>();
            _bob = new HeadBob(_bobAmount, _bobSpeed);
            _controls = new GameControls();

            if (_head == null)
            {
                Debug.LogError("Контроллеру не назначена голова — обзор работать не будет", this);
                return;
            }

            _headBasePosition = _head.localPosition;
        }

        private void OnEnable()
        {
            _controls.Player.Enable();
            _controls.Player.Flashlight.performed += OnFlashlightPressed;
            _controls.Player.Interact.performed += OnInteractPressed;
            _controls.Player.Pause.performed += OnPausePressed;

            SetCursorLocked(true);
        }

        private void OnDisable()
        {
            _controls.Player.Flashlight.performed -= OnFlashlightPressed;
            _controls.Player.Interact.performed -= OnInteractPressed;
            _controls.Player.Pause.performed -= OnPausePressed;
            _controls.Player.Disable();

            SetCursorLocked(false);
        }

        private void OnDestroy()
        {
            _controls?.Dispose();
        }

        private void Update()
        {
            var deltaTime = Time.deltaTime;

            UpdateLook(deltaTime);
            var isMoving = UpdateMovement(deltaTime);
            UpdateHead(deltaTime, isMoving);
        }

        private void UpdateLook(float deltaTime)
        {
            if (_head == null)
            {
                return;
            }

            var look = _controls.Player.Look.ReadValue<Vector2>();

            // Мышь отдаёт пиксели за кадр, стик — отклонение от -1 до 1.
            // Первое уже за кадр, второе нужно домножить на время.
            var isStick = _controls.Player.Look.activeControl?.device is Gamepad;
            var delta = isStick
                ? look * (_stickSensitivity * deltaTime)
                : look * _mouseSensitivity;

            transform.Rotate(Vector3.up, delta.x, Space.World);

            // Не даём свернуть шею.
            _pitch = Mathf.Clamp(_pitch - delta.y, -_pitchLimit, _pitchLimit);
        }

        /// <summary>Двигает тело и сообщает, идёт ли игрок.</summary>
        private bool UpdateMovement(float deltaTime)
        {
            var input = _controls.Player.Move.ReadValue<Vector2>();
            IsRunning = _controls.Player.Sprint.IsPressed();

            var direction = transform.right * input.x + transform.forward * input.y;
            if (direction.sqrMagnitude > 1f)
            {
                direction.Normalize();
            }

            if (_body.isGrounded && _verticalVelocity < 0f)
            {
                _verticalVelocity = GroundStick;
            }
            else
            {
                _verticalVelocity += Physics.gravity.y * deltaTime;
            }

            var speed = IsRunning ? _runSpeed : _walkSpeed;
            var velocity = direction * speed + Vector3.up * _verticalVelocity;
            _body.Move(velocity * deltaTime);

            return direction.magnitude > MovingThreshold;
        }

        private void UpdateHead(float deltaTime, bool isMoving)
        {
            if (_head == null)
            {
                return;
            }

            // Качание только на земле: в воздухе шагов нет.
            if (_bob.Advance(deltaTime, isMoving && _body.isGrounded))
            {
                StepTaken?.Invoke();
            }

            _head.localPosition = _headBasePosition + Vector3.up * _bob.VerticalOffset;
            _head.localRotation = Quaternion.Euler(_pitch, 0f, _bob.Roll * Mathf.Rad2Deg);
        }

        private void OnFlashlightPressed(InputAction.CallbackContext _)
        {
            if (_flashlight != null)
            {
                _flashlight.Toggle();
            }
        }

        private void OnInteractPressed(InputAction.CallbackContext _)
        {
            if (_interactor != null)
            {
                _interactor.TryInteract();
            }
        }

        /// <summary>
        /// До появления меню паузы Escape просто отпускает курсор — иначе
        /// из игры не выбраться ни в редакторе, ни в билде.
        /// </summary>
        private void OnPausePressed(InputAction.CallbackContext _)
        {
            SetCursorLocked(Cursor.lockState != CursorLockMode.Locked);
        }

        private static void SetCursorLocked(bool isLocked)
        {
            Cursor.lockState = isLocked ? CursorLockMode.Locked : CursorLockMode.None;
            Cursor.visible = !isLocked;
        }
    }
}
