```Mermaid.js
graph TD
    %% === EXECUTION ORCHESTRATION ===
    subgraph Game_Loop [Game Loop - main.lua]
        LOAD[love.load<br/>Initialize Systems]
        UPDATE[love.update<br/>Run System Scheduler]
        DRAW[love.draw<br/>Run Render Systems]
    end
    
    subgraph System_Scheduler [System Scheduler]
        SCHED[Process Systems in Order<br/>Handle Event Queue]
        CONFIG[Inject World Config<br/>gravity, bounds, etc.]
    end

    %% === SYSTEM A: MOVEMENT ===
    subgraph System_Movement [movement.lua]
        direction TB
        
        subgraph SM_Shell [System Shell - The Only Impure Layer]
            SM_UPDATE["movement.update(world, dt, config)<br/>------------------<br/>READS: Query & Extract Components<br/>COMPUTES: Call Orchestrators<br/>WRITES: Apply Results + Emit Events"]
        end
        
        subgraph SM_Orchestrators [Orchestrators - Pure/Near-Pure]
            SM_ORCH1["compute_physics_step(<br/>pos, vel, mass, dt, gravity)<br/>------------------<br/>Returns: {position, velocity}"]
            SM_ORCH2["compute_boundary_check(<br/>pos, bounds)<br/>------------------<br/>Returns: {clamped_pos, hit_boundary}"]
        end
        
        subgraph SM_Pure [Pure Functions - Math & Logic]
            SM_PURE1[calculate_acceleration<br/>gravity, mass → accel]
            SM_PURE2[apply_velocity<br/>pos, vel, dt → new_pos]
            SM_PURE3[clamp_to_bounds<br/>value, min, max → clamped]
        end
    end

    %% === SYSTEM B: COMBAT ===
    subgraph System_Combat [combat.lua]
        direction TB
        
        subgraph SC_Shell [System Shell - The Only Impure Layer]
            SC_UPDATE["combat.update(world, dt, config)<br/>------------------<br/>READS: Query & Extract Components<br/>COMPUTES: Call Orchestrators<br/>WRITES: Apply Results + Emit Events"]
        end
        
        subgraph SC_Orchestrators [Orchestrators - Pure/Near-Pure]
            SC_ORCH1["compute_damage_result(<br/>atk_stats, def_stats, modifiers)<br/>------------------<br/>Returns: {damage, events}"]
        end
        
        subgraph SC_Pure [Pure Functions - Math & Logic]
            SC_PURE1[calculate_base_damage<br/>attack, defense → damage]
            SC_PURE2[apply_damage_modifiers<br/>damage, mods → final_damage]
        end
    end

    %% === DATA LAYER ===
    subgraph ECS_World [ECS World - Components & Events]
        direction LR
        COMP_POS[(Position<br/>Component)]
        COMP_VEL[(Velocity<br/>Component)]
        COMP_STATS[(Stats<br/>Component)]
        EVENT_Q[Event Queue<br/>collision, death, etc.]
    end

    %% === EXECUTION FLOW ===
    UPDATE --> SCHED
    SCHED --> CONFIG
    SCHED --> SM_UPDATE
    SCHED --> SC_UPDATE
    
    %% Movement System Flow
    SM_UPDATE -->|"Explicit Params<br/>(pos, vel, mass, dt, gravity)"| SM_ORCH1
    SM_UPDATE -->|"Explicit Params<br/>(pos, bounds)"| SM_ORCH2
    
    SM_ORCH1 --> SM_PURE1
    SM_ORCH1 --> SM_PURE2
    SM_ORCH2 --> SM_PURE3
    
    %% Combat System Flow
    SC_UPDATE -->|"Explicit Params<br/>(atk_stats, def_stats, mods)"| SC_ORCH1
    SC_ORCH1 --> SC_PURE1
    SC_ORCH1 --> SC_PURE2

    %% === DATA FLOW ===
    %% Shells READ from world
    SM_UPDATE -.->|"Query(Position, Velocity, Mass)<br/>Read Components"| COMP_POS
    SM_UPDATE -.->|Read| COMP_VEL
    SC_UPDATE -.->|"Query(Stats, Health)<br/>Read Components"| COMP_STATS
    
    %% Pure functions RETURN values up
    SM_PURE1 -.->|"Returns Value"| SM_ORCH1
    SM_PURE2 -.->|"Returns Value"| SM_ORCH1
    SM_PURE3 -.->|"Returns Value"| SM_ORCH2
    SC_PURE1 -.->|"Returns Value"| SC_ORCH1
    SC_PURE2 -.->|"Returns Value"| SC_ORCH1
    
    %% Orchestrators RETURN results
    SM_ORCH1 -.->|"Returns Data"| SM_UPDATE
    SM_ORCH2 -.->|"Returns Data"| SM_UPDATE
    SC_ORCH1 -.->|"Returns Data + Events"| SC_UPDATE
    
    %% Shells WRITE to world
    SM_UPDATE -.->|"Write Results"| COMP_POS
    SM_UPDATE -.->|"Write Results"| COMP_VEL
    SC_UPDATE -.->|"Write Results + Enqueue Events"| EVENT_Q
    
    %% === PROHIBITED INTERACTIONS ===
    SM_UPDATE -.->|"❌ PROHIBITED<br/>Systems Don't Call Systems"| SC_UPDATE
    SM_ORCH1 -.->|"❌ PROHIBITED<br/>No World Access Below Shell"| COMP_POS
    SC_ORCH1 -.->|"❌ PROHIBITED<br/>No World Access Below Shell"| COMP_STATS

    %% === ARCHITECTURAL RULES ===
    subgraph Rules [Defensive Architecture Rules]
        direction TB
        R1["✓ All dependencies visible in function signatures"]
        R2["✓ Only shells touch world state"]
        R3["✓ Orchestrators & pure functions return values only"]
        R4["✓ Systems communicate via events, not calls"]
        R5["✓ Component queries declare exact dependencies"]
        R6["✓ Config injected once, not grabbed from context"]
    end
    
    %% Connect rules to relevant parts
    CONFIG -.->|"Enforces"| R6
    SM_UPDATE -.->|"Enforces"| R2
    SM_UPDATE -.->|"Enforces"| R5
    SM_ORCH1 -.->|"Enforces"| R1
    EVENT_Q -.->|"Enforces"| R4

    %% Force vertical layout
    SM_PURE3 ~~~ COMP_POS
    SC_PURE2 ~~~ EVENT_Q
```