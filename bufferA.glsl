/*
  Title: Cortical Drift — An Emergent Simulation of Post-Lesion
         Cortical Remapping Using Competing Reaction-Diffusion Agents
 
  INTERACTIONS:
    - Mouse click/hold: introduces a lesion at cursor position (84px radius)
    - Multiple clicks supported — each adds a new lesion, watch them compete
      for the same vacant territory
    - Let the system run for 10-15 seconds before clicking to allow wave
      dynamics to develop fully
    - Reload/restart: reseeds territory map with fresh random micro-damage
    - Interesting parameters to modify:
        PLASTICITY_RATE (Buffer A) — higher = faster recolonization
        LESION_RADIUS (Buffer A)   — controls damage zone size
 
  DESCRIPTION:
    This system models post-stroke cortical remapping as an emergent
    competition between four neural populations over a shared chemical
    signalling field. The biological phenomenon it abstracts is well
    documented: after focal cortical injury, surviving neighbouring regions
    do not remain static but actively compete to recolonize the damaged
    territory through a process of axonal sprouting and synaptic
    reorganization (Nudo et al., 1996). Critically, this remapping can
    take two clinically distinct forms — perilesional recovery, where the
    correct anatomically adjacent region expands into the lesion site
    (adaptive), or vicarious remapping, where a distal non-homologous
    region invades the vacancy (maladaptive). The same underlying local
    rules produce both outcomes depending on parameters, which is the
    central emergent result of this simulation.
 
    The system combines three coupled computational paradigms. The chemical
    signalling field (Buffer B) is a four-species reaction-diffusion system
    inspired by Turing (1952), where each species represents one population's
    attractant concentration. The wave activity field (Buffer C) is an
    excitable medium modelled after the Hodgepodge machine, producing
    travelling waves of activation that propagate within population
    territories and drive territorial expansion through a Hebbian feedback
    loop — populations that sustain coherent wave propagation expand more
    aggressively. The territory map (Buffer A) arbitrates between these two
    fields stochastically, implementing probabilistic recolonization rules
    analogous to cellular automata with continuous state. The three buffers
    form a closed feedback loop: damage drives chemical emission, chemical
    gradients guide recolonization, and wave activity biases which population
    wins the competition. No single buffer controls the outcome — the
    remapping regime emerges from their interaction.
 
    The system is a qualitative rather than quantitative model. It does not
    simulate individual neurons or precise synaptic geometry. Its value lies
    in demonstrating that the clinically observed distinction between adaptive
    and maladaptive remapping can emerge from a small set of local competitive
    rules without being explicitly programmed. This connects to the broader
    argument in neural field theory that macroscopic cortical dynamics arise
    from local excitatory and inhibitory interactions (Ermentrout & Cowan,
    1979), and to the principle that experience-dependent plasticity is
    governed by activity-dependent competition between populations
    (Buonomano & Merzenich, 1998).
 
  ACADEMIC REFERENCES:
    Buonomano, D. V., & Merzenich, M. M. (1998). Cortical plasticity: From
      synapses to maps. Annual Review of Neuroscience, 21, 149-186.
    Ermentrout, G. B., & Cowan, J. D. (1979). A mathematical theory of
      visual hallucination patterns. Biological Cybernetics, 34(3), 137-150.
    Nudo, R. J., Wise, B. M., SiFuentes, F., & Milliken, G. W. (1996).
      Neural substrates for the effects of rehabilitative training on motor
      recovery after ischemic infarct. Science, 272(5269), 1791-1794.
    Turing, A. M. (1952). The chemical basis of morphogenesis.
      Philosophical Transactions of the Royal Society B, 237(641), 37-72.
    Jones, J. (2010). Characteristics of pattern formation and evolution in
      approximations of Physarum transport networks. Artificial Life,
      16(2), 127-153.
 
  TECHNICAL REALIZATION:
    The system uses four shader tabs in a closed feedback architecture:
 
    BUFFER A (Territory & Lesion Map) — stores population ownership and
    damage per pixel. Implements Voronoi initialization, mouse-driven
    lesion application, 8-neighbour probabilistic recolonization guided
    by Buffer B signal and Buffer C wave activity, and dual healing rates
    for owned vs vacant pixels. Spontaneous micro-damage perturbations
    keep the system dynamic between user interactions.
 
    BUFFER B (Chemical Signalling Field) — four-channel reaction-diffusion
    field. Each channel holds one population's attractant concentration.
    Laplacian diffusion spreads signal spatially each frame. Vacant pixels
    emit into all channels (recovery broadcast); owned pixels emit into
    their own channel only (lateral inhibition). The spatial gradient of
    this field is the primary mechanism determining which population wins
    recolonization — closer populations have stronger signal at the lesion
    site, naturally producing perilesional recovery.
 
    BUFFER C (Excitable Medium / Wave Activity) — Hodgepodge machine-
    inspired three-state excitable medium (quiescent, excited, refractory).
    Waves propagate only within same-population territory. Rare spontaneous
    ignition seeds new wave fronts. Post-lesion hyperexcitability modelled
    by boosting activity in recently healed pixels. Wave activity feeds
    back into Buffer A to bias territorial expansion toward more active
    populations, implementing a Hebbian competitive advantage.
 
    IMAGE TAB (fMRI False-Colour Render) — composites all three buffers
    into a functional MRI-inspired visualisation. Population territories
    render as distinct cool blue/violet hues. Wave fronts push pixels up
    the fMRI colour ramp (blue->cyan->green->yellow->red->white). Sobel
    edge detection highlights territory borders as cyan lines. Lesion
    sites render as dark voids with necrotic rims and blue penumbral halos.
    No simulation logic runs in this tab.
 
  FUTURE EXTENSIONS:
    - Inhibitory surround field modelling GABAergic suppression of
      vicarious regions, which would make the perilesional/vicarious
      distinction sharper and more controllable
    - Spreading cortical depolarisation wave following lesion, modelling
      the secondary damage wave observed clinically after stroke
    - User-controlled therapy brush that boosts perilesional activity,
      allowing interactive exploration of rehabilitation interventions
    - True refractory period timer per pixel for more realistic oscillatory
      dynamics closer to Hodgkin-Huxley spiking behaviour
 
  SOURCES:
    Course notes and systems explored: SmoothLife (Assignment 2),
    Gray-Scott reaction-diffusion, Physarum chemotaxis (Assignment 3),
    Hodgepodge excitable medium, Voronoi spatial partitioning.
    External: all academic references listed above.
 */


#define LESION_RADIUS 84.0
#define PLASTICITY_RATE 0.08

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float initTerritory(vec2 uv) {
    vec2 seeds[4];
    seeds[0] = vec2(0.20, 0.25);
    seeds[1] = vec2(0.78, 0.22);
    seeds[2] = vec2(0.25, 0.78);
    seeds[3] = vec2(0.72, 0.75);

    float minDist = 999.0;
    float owner = 1.0;
    for (int i = 0; i < 4; i++) {
        float d = distance(uv, seeds[i]);
        if (d < minDist) {
            minDist = d;
            owner = float(i + 1);
        }
    }
    return owner;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;

    // clean init — no initial damage
       if (iFrame == 0) {
        float pop = initTerritory(uv);
        // very sparse initial damage — only ~5% of pixels
        // uses two independent hashes to avoid patterns
        float r1 = hash(uv * 23.3 + vec2(1.7, 4.2));
        float r2 = hash(uv * 11.1 + vec2(8.3, 2.9));
        float initDamage = (r1 > 0.95 && r2 > 0.5) ? r2 * 0.7 : 0.0;
        fragColor = vec4(pop, initDamage, 0.0, 1.0);
        return;
    }

    vec4 prev = texture(iChannel0, uv);
    float popID = prev.r;
    float damage = prev.g;

    vec4 signal = texture(iChannel1, uv);
    float activity = texture(iChannel2, uv).r;

    // mouse lesion
    if (iMouse.z > 0.0) {
        float d = distance(fragCoord, iMouse.xy);
        if (d < LESION_RADIUS) {
            float strength = 1.0 - smoothstep(0.0, LESION_RADIUS, d);
            damage = max(damage, strength);
            if (damage > 0.8) popID = 0.0;
        }
    }

    // spontaneous micro-damage keeps system dynamic
    float randDamage = hash(uv + fract(iTime * 0.05));
    float spatialNoise = hash(uv * 7.3 + fract(iTime * 0.01));
    if (randDamage > 0.9995 && spatialNoise > 0.3) {
        damage = max(damage, 0.4);
    }

    // recolonization — 8 directions
    if (popID == 0.0 && damage < 0.75) {
        float bestScore = 0.0;
        float bestPop = 0.0;

        vec2 dirs[8];
        dirs[0] = vec2( texel.x,  0.0);
        dirs[1] = vec2(-texel.x,  0.0);
        dirs[2] = vec2( 0.0,      texel.y);
        dirs[3] = vec2( 0.0,     -texel.y);
        dirs[4] = vec2( texel.x,  texel.y);
        dirs[5] = vec2(-texel.x,  texel.y);
        dirs[6] = vec2( texel.x, -texel.y);
        dirs[7] = vec2(-texel.x, -texel.y);

        for (int i = 0; i < 8; i++) {
            vec4 nb = texture(iChannel0, uv + dirs[i]);
            float nbPop = nb.r;
            float nbDmg = nb.g;

            if (nbPop > 0.0 && nbDmg < 0.7) {
                float sig = signal[int(nbPop) - 1];
                float nbActivity = texture(iChannel2, uv + dirs[i]).r;
                float score = sig + nbActivity * 0.35;
                if (score > bestScore) {
                    bestScore = score;
                    bestPop = nbPop;
                }
            }
        }

        if (bestPop > 0.0 && hash(uv + fract(iTime)) < PLASTICITY_RATE * bestScore) {
            popID = bestPop;
            damage = 0.35;
        }
    }

    // fast healing for owned pixels
    if (popID > 0.0) {
        damage = max(0.0, damage - 0.006);
    }

    // passive healing for vacant pixels
    if (popID == 0.0) {
        damage = max(0.0, damage - 0.002);
    }

    fragColor = vec4(popID, damage, 0.0, 1.0);
}
