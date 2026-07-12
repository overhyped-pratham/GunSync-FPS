// GunSync FPS — EnemyAI
// NavMesh-based enemy with Patrol → Alert → Chase → Attack → Dead states.
//
// SETUP:
// 1. Add NavMeshAgent component to enemy GameObject
// 2. Add this script to enemy prefab
// 3. Bake NavMesh in Window > AI > Navigation
// 4. Set patrol points in Inspector
// 5. Tag enemy as "Enemy" for hit detection

using System.Collections;
using UnityEngine;
using UnityEngine.AI;

namespace GunSync
{
    public enum EnemyState
    {
        Patrol,
        Alert,
        Chase,
        Attack,
        Dead,
    }

    [RequireComponent(typeof(NavMeshAgent))]
    public class EnemyAI : MonoBehaviour
    {
        [Header("Stats")]
        public float maxHealth = 100f;
        public float moveSpeed = 3.5f;
        public float chaseSpeed = 5.5f;
        public float attackDamage = 15f;
        public float attackRate = 1.2f;    // attacks per second
        public float attackRange = 2.5f;   // melee range

        [Header("Detection")]
        public float sightRange = 20f;
        public float sightAngle = 110f;
        public float hearRange = 10f;

        [Header("Patrol")]
        public Transform[] patrolPoints;
        public float patrolWaitTime = 2f;

        [Header("References")]
        public Transform playerTransform;
        public Animator animator;

        // ── Private state
        private NavMeshAgent _agent;
        private float _health;
        private EnemyState _state = EnemyState.Patrol;
        private int _patrolIndex = 0;
        private float _nextAttackTime = 0f;
        private bool _waiting = false;

        private static readonly int AnimMove = Animator.StringToHash("Speed");
        private static readonly int AnimAttack = Animator.StringToHash("Attack");
        private static readonly int AnimDead = Animator.StringToHash("Dead");

        // ─────────────────────────────────────────────

        private void Awake()
        {
            _agent = GetComponent<NavMeshAgent>();
            _health = maxHealth;

            if (animator == null) animator = GetComponent<Animator>();

            // Find player if not assigned
            if (playerTransform == null)
            {
                var player = GameObject.FindGameObjectWithTag("Player");
                if (player != null) playerTransform = player.transform;
            }
        }

        private void Start()
        {
            _agent.speed = moveSpeed;
            if (patrolPoints != null && patrolPoints.Length > 0)
                GoToPatrolPoint();
        }

        private void Update()
        {
            if (_state == EnemyState.Dead) return;

            switch (_state)
            {
                case EnemyState.Patrol:  UpdatePatrol();  break;
                case EnemyState.Alert:   UpdateAlert();   break;
                case EnemyState.Chase:   UpdateChase();   break;
                case EnemyState.Attack:  UpdateAttack();  break;
            }

            UpdateAnimator();
        }

        // ─────────────────────────────────────────────
        // State Updates
        // ─────────────────────────────────────────────

        private void UpdatePatrol()
        {
            if (CanSeePlayer())
            {
                TransitionTo(EnemyState.Chase);
                return;
            }

            if (patrolPoints == null || patrolPoints.Length == 0) return;

            if (!_agent.pathPending && _agent.remainingDistance < 0.5f && !_waiting)
            {
                StartCoroutine(PatrolWait());
            }
        }

        private void UpdateAlert()
        {
            if (CanSeePlayer())
            {
                TransitionTo(EnemyState.Chase);
            }
        }

        private void UpdateChase()
        {
            if (playerTransform == null) return;

            float dist = Vector3.Distance(transform.position, playerTransform.position);

            if (dist <= attackRange)
            {
                TransitionTo(EnemyState.Attack);
                return;
            }

            if (!CanSeePlayer() && dist > sightRange * 1.5f)
            {
                TransitionTo(EnemyState.Patrol);
                return;
            }

            _agent.SetDestination(playerTransform.position);
        }

        private void UpdateAttack()
        {
            if (playerTransform == null) return;

            float dist = Vector3.Distance(transform.position, playerTransform.position);

            if (dist > attackRange * 1.4f)
            {
                TransitionTo(EnemyState.Chase);
                return;
            }

            // Face player
            transform.LookAt(new Vector3(
                playerTransform.position.x,
                transform.position.y,
                playerTransform.position.z));

            if (Time.time >= _nextAttackTime)
            {
                _nextAttackTime = Time.time + (1f / attackRate);
                animator?.SetTrigger(AnimAttack);
                // In a full game, deal damage to player here
                Debug.Log($"[Enemy] {name} attacks player for {attackDamage}");
            }
        }

        // ─────────────────────────────────────────────
        // Public API
        // ─────────────────────────────────────────────

        /// <summary>Apply damage. Returns true if this shot killed the enemy.</summary>
        public bool TakeDamage(float damage, Vector3 hitPoint)
        {
            if (_state == EnemyState.Dead) return false;

            _health -= damage;
            Debug.Log($"[Enemy] {name} took {damage} dmg — HP={_health:F0}");

            // React to being shot
            if (_state == EnemyState.Patrol || _state == EnemyState.Alert)
                TransitionTo(EnemyState.Chase);

            if (_health <= 0f)
            {
                Die();
                return true; // killed
            }

            return false; // just hit
        }

        // ─────────────────────────────────────────────
        // Private Helpers
        // ─────────────────────────────────────────────

        private bool CanSeePlayer()
        {
            if (playerTransform == null) return false;

            Vector3 toPlayer = playerTransform.position - transform.position;
            float dist = toPlayer.magnitude;

            if (dist > sightRange) return false;

            float angle = Vector3.Angle(transform.forward, toPlayer.normalized);
            if (angle > sightAngle * 0.5f) return false;

            // Line of sight check
            if (Physics.Raycast(transform.position + Vector3.up * 1.5f,
                toPlayer.normalized, out RaycastHit hit, sightRange))
            {
                return hit.collider.CompareTag("Player");
            }

            return false;
        }

        private void TransitionTo(EnemyState newState)
        {
            if (_state == newState) return;
            _state = newState;

            switch (newState)
            {
                case EnemyState.Chase:
                    _agent.speed = chaseSpeed;
                    _agent.isStopped = false;
                    break;
                case EnemyState.Patrol:
                    _agent.speed = moveSpeed;
                    _agent.isStopped = false;
                    GoToPatrolPoint();
                    break;
                case EnemyState.Attack:
                    _agent.isStopped = true;
                    _agent.velocity = Vector3.zero;
                    break;
            }
        }

        private void GoToPatrolPoint()
        {
            if (patrolPoints.Length == 0) return;
            _agent.SetDestination(patrolPoints[_patrolIndex].position);
            _patrolIndex = (_patrolIndex + 1) % patrolPoints.Length;
        }

        private IEnumerator PatrolWait()
        {
            _waiting = true;
            _agent.isStopped = true;
            yield return new WaitForSeconds(patrolWaitTime);
            _agent.isStopped = false;
            _waiting = false;
            GoToPatrolPoint();
        }

        private void Die()
        {
            _state = EnemyState.Dead;
            _agent.isStopped = true;
            _agent.enabled = false;
            animator?.SetTrigger(AnimDead);

            // Disable collider so player can walk through corpse
            var col = GetComponent<Collider>();
            if (col != null) col.enabled = false;

            // Destroy after 5 seconds
            Destroy(gameObject, 5f);

            Debug.Log($"[Enemy] {name} is dead ☠️");
        }

        private void UpdateAnimator()
        {
            if (animator == null) return;
            animator.SetFloat(AnimMove, _agent.velocity.magnitude);
        }

        private void OnDrawGizmosSelected()
        {
            // Visualize sight range
            Gizmos.color = Color.yellow;
            Gizmos.DrawWireSphere(transform.position, sightRange);
            Gizmos.color = Color.red;
            Gizmos.DrawWireSphere(transform.position, attackRange);
        }
    }
}
