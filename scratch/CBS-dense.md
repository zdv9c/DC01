# Context-Based Steering (CBS) Implementation Spec

## 1. Core Data Structures

**Context Map (Per Agent):**

- `N` (Resolution): Integer (e.g., 8, 16, 32). Higher = smoother, costlier.
    
- `Slots`: Array of `N` normalized 2D vectors representing radial directions.
    
    - $\vec{d}_i = [\cos(2\pi i / N), \sin(2\pi i / N)]$
        
- `Interest`: Array of `N` floats $[0.0, 1.0]$. Represents _desire_ to move.
    
- `Danger`: Array of `N` floats $[0.0, 1.0]$. Represents _obstruction_.
    

## 2. Pipeline Execution (Per Frame)

1. **Reset:** `Interest` = 0.0, `Danger` = 0.0.
    
2. **Evaluate Behaviors:** Run active behaviors (Seek, Strafe, Wander) to populate `Interest`.
    
3. **Evaluate Sensors:** Run raycasts/proximity checks to populate `Danger`.
    
4. **Solver:**
    
    - Mask: $I_{final}[i] = I[i] \times (1.0 - D[i])$
        
    - Select: Find index $k$ with max $I_{final}$.
        
    - Interpolate: Calculate sub-slot steering vector.
        
5. **Actuate:** Apply force/velocity towards final vector.
    

## 3. Shaping Functions (Interest Generation)

Behaviors map the relationship between agent direction $\vec{d}_i$ and target vector $\vec{t}$ to a scalar weight.

Base Metric: Dot Product

$$dp_i = \vec{d}_i \cdot \vec{t}$$

### A. Seek / Chase

Maximize movement toward target.

$$I[i] = \max(0.0, dp_i)$$

### B. Strafe / Circle

Maximize movement perpendicular to target (Dot Product $\approx$ 0).

$$I[i] = 1.0 - |dp_i|$$

- **Logic:** $dp=1$ (Forward) $\to 0.0$. $dp=0$ (Side) $\to 1.0$.
    
- **Distance Blending:** Linearly interpolate between **Seek** and **Strafe** maps based on distance to target.
    
    - `if dist > max_range`: use Seek.
        
    - `if dist < min_range`: use Flee (or negative Seek).
        
    - `else`: use Strafe.
        

### C. Angled Separation (Anti-Jitter)

Avoids "tug-of-war" oscillation by favoring escape at angles rather than directly opposite.

Given neighbor direction $\vec{n}$:

1. Calculate repulsion vector $\vec{r} = -\vec{n}$.
    
2. Define desired escape angles (e.g., $\pm 45^\circ$ from $\vec{r}$).
    
3. Map interest peaks to these angled vectors, not pure $\vec{r}$.
    

## 4. Wandering (OpenSimplex Noise)

Replaces random jitter with coherent "meandering."

1. **State:** Maintain `noise_cursor` (time/position index).
    
2. **Sample:** $val = \text{OpenSimplexNoise}(\text{noise\_cursor})$. Range $[-1, 1]$.
    
3. **Map:** Convert $val$ to angular offset $\theta_{offset}$.
    
4. **Vector:** $\vec{t}_{wander} = \text{Agent.Forward rotated by } \theta_{offset}$.
    
5. **Apply:** Use **Seek** shaping function on $\vec{t}_{wander}$.
    
6. **Tether:** Blend with a "Return to Spawn" vector if `dist_to_spawn > leash_radius`.
    

## 5. Sensory Input (Danger Map)

1. **Raycast:** Cast ray for every slot $i$ (or strided subset) up to `look_ahead` distance.
    
2. **Weighting:** $D[i] = 1.0 - (\text{hit\_distance} / \text{look\_ahead})$.
    
    - Near obstacles = 1.0 (Hard block).
        
    - Far obstacles = ~0.1 (Soft avoidance).
        
3. **Dilation (Danger Skirt):** If slot $i$ hits, apply Gaussian or linear falloff to neighbors $i-1, i+1$ to account for agent radius.
    

## 6. Solver & Sub-Slot Interpolation

Naive selection of the max slot causes snapping (16 slots = 22.5° steps). Use parabolic interpolation to find the true peak.

**Algorithm:**

1. Find index $c$ where $I_{final}[c]$ is maximum.
    
2. Get neighbors: $L = I_{final}[c-1]$, $R = I_{final}[c+1]$ (handle wrapping).
    
3. Calculate offset $x$ relative to $c$ (range $[-0.5, 0.5]$):
    
    $$x = \frac{L - R}{2(L - 2I_{final}[c] + R)}$$
    
4. **Final Heading:** $\theta_{final} = \theta_c + (x \times \frac{2\pi}{N})$
    
5. Convert $\theta_{final}$ to vector.
    

## 7. Optimization Notes

- **Structure of Arrays (SoA):** Store all Interest/Danger maps in contiguous memory for cache locality.
    
- **SIMD:** Use vector intrinsics for map operations (Masking is just a vector multiply).
    
- **LOD:** Reduce $N$ or update frequency based on distance from camera.