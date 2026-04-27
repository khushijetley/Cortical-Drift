/*
  IMAGE TAB — fMRI False-Colour Composite Render
 
  This tab contains no simulation logic. It reads the three simulation
  buffers and composites them into a final visualisation inspired by
  functional MRI (fMRI) BOLD activation maps used in neuroimaging.
 
  Visual elements and their sources:
 
    TERRITORY COLOUR (Buffer A) — each population has a distinct resting
    activation level mapped through an fMRI colour ramp:
    deep violet -> blue -> cyan -> green -> yellow -> red -> white.
    At rest, territories appear as distinct cool blue/violet regions.
 
    WAVE ACTIVITY (Buffer C) — excitation state shifts pixels up the
    colour ramp. Travelling wave fronts appear as brief green flashes
    moving across territories. Post-lesion hyperactive zones pulse
    warmer than surrounding tissue, visually marking recovery sites.
 
    TERRITORY BORDERS (Buffer A) — a Sobel edge detection pass identifies
    boundaries between populations. Borders glow cyan-white, resembling
    cortical sulci visible on structural MRI scans.
 
    LESION VOID (Buffer A) — heavily damaged pixels render as stark black
    voids with a grey-white necrotic rim, mimicking T2 hyperintensity
    appearance of stroke lesions on clinical MRI scans.
 
    ISCHAEMIC PENUMBRA (Buffer B) — the diffusing chemical signal field
    creates a faint blue halo around lesion sites, representing the
    at-risk penumbral tissue visible on diffusion-weighted imaging (DWI).
 
    RECOVERY SHIMMER — recolonizing pixels shimmer with a warm green
    tinge, showing BOLD signal gradually returning as territory recovers.
 
    LIVE LESION RING — while mouse is held, a pulsing red-white ring
    marks the active damage radius so the user can see lesion extent.
 
  Reads from: iChannel0 (Buffer A), iChannel1 (Buffer B), iChannel2 (Buffer C)
 */


vec3 fmriRamp(float t) {
    t = clamp(t, 0.0, 1.0);
    vec3 c0 = vec3(0.05, 0.02, 0.20);
    vec3 c1 = vec3(0.10, 0.10, 0.65);
    vec3 c2 = vec3(0.05, 0.55, 0.75);
    vec3 c3 = vec3(0.10, 0.80, 0.30);
    vec3 c4 = vec3(0.95, 0.85, 0.05);
    vec3 c5 = vec3(0.98, 0.30, 0.02);
    vec3 c6 = vec3(1.00, 1.00, 1.00);

    if (t < 0.17) return mix(c0, c1, t / 0.17);
    if (t < 0.33) return mix(c1, c2, (t - 0.17) / 0.16);
    if (t < 0.50) return mix(c2, c3, (t - 0.33) / 0.17);
    if (t < 0.67) return mix(c3, c4, (t - 0.50) / 0.17);
    if (t < 0.83) return mix(c4, c5, (t - 0.67) / 0.16);
                  return mix(c5, c6, (t - 0.83) / 0.17);
}

// wide spread resting levels so 4 regions look distinct at rest
float restLevel(float popID) {
    if (popID < 1.5) return 0.05;
    if (popID < 2.5) return 0.22;
    if (popID < 3.5) return 0.13;
                     return 0.30;
}

// sobel edge — finds borders between populations
float border(vec2 uv, vec2 tex) {
    float tl = texture(iChannel0, uv + vec2(-tex.x,  tex.y)).r;
    float tc = texture(iChannel0, uv + vec2( 0.0,    tex.y)).r;
    float tr = texture(iChannel0, uv + vec2( tex.x,  tex.y)).r;
    float ml = texture(iChannel0, uv - vec2( tex.x,  0.0  )).r;
    float mr = texture(iChannel0, uv + vec2( tex.x,  0.0  )).r;
    float bl = texture(iChannel0, uv - vec2( tex.x,  tex.y)).r;
    float bc = texture(iChannel0, uv - vec2( 0.0,    tex.y)).r;
    float br = texture(iChannel0, uv - vec2( tex.x,  tex.y)).r;
    float gx = -tl - 2.0*ml - bl + tr + 2.0*mr + br;
    float gy = -tl - 2.0*tc - tr + bl + 2.0*bc + br;
    return clamp(length(vec2(gx, gy)) * 0.5, 0.0, 1.0);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 tex = 1.0 / iResolution.xy;

    vec4 territory = texture(iChannel0, uv);
    vec4 signal    = texture(iChannel1, uv);
    vec4 hebbian   = texture(iChannel2, uv);

    float popID   = territory.r;
    float damage  = territory.g;
    float activity = hebbian.r;

    // hard cap at 0.4 so territories never go above green at rest
    // only strong wave fronts push into yellow/red briefly
    float activation = clamp(restLevel(popID) + activity * 0.35, 0.0, 0.4);
    activation *= (1.0 - damage * 0.95);

    vec3 col = fmriRamp(activation);

    // vacant pixels are black
    if (popID < 0.5) col = vec3(0.0);

    // blue penumbra halo around lesion — ischaemic penumbra
    float totalSig = (signal.r + signal.g + signal.b + signal.a) * 0.25;
    if (popID < 0.5 || damage > 0.3) {
        col += vec3(0.03, 0.06, 0.25) * totalSig * 0.6;
    }

    // territory borders glow cyan
    float e = border(uv, tex);
    col = mix(col, vec3(0.3, 0.85, 1.0), e * 0.8);

    // lesion core and necrotic rim
    float lesionCore = smoothstep(0.4, 0.85, damage);
    float lesionRim  = smoothstep(0.25, 0.45, damage)
                     * (1.0 - smoothstep(0.45, 0.65, damage));
    col = mix(col, vec3(0.02, 0.01, 0.03), lesionCore * 0.95);
    col = mix(col, vec3(0.65, 0.68, 0.72), lesionRim * 0.5);

    // live lesion ring while mouse held
    if (iMouse.z > 0.0) {
        float d = distance(fragCoord, iMouse.xy);
        float fill = 1.0 - smoothstep(0.0, 84.0, d);
        col = mix(col, vec3(0.02, 0.01, 0.03), fill * 0.9);
        float ring = 1.0 - abs(d - 71.0) / 10.0;
        ring = clamp(ring, 0.0, 1.0);
        float pulse = 0.5 + 0.5 * sin(iTime * 9.0);
        col = mix(col, vec3(1.0, 0.3, 0.1), ring * pulse * 0.85);
    }

    // recovery shimmer — warm green on recolonizing pixels
    float recovering = smoothstep(0.05, 0.3, damage)
                     * (1.0 - smoothstep(0.3, 0.6, damage))
                     * step(0.5, popID);
    float shimmer = 0.5 + 0.5 * sin(iTime * 2.5 + hash(uv) * 6.28);
    col += vec3(0.25, 0.5, 0.1) * recovering * shimmer * 0.3;

    // subtle mri scan noise
    col += vec3((hash(uv + fract(iTime)) - 0.5) * 0.025);

    // vignette
    col *= 1.0 - 0.5 * pow(length(uv - 0.5) * 1.8, 2.2);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
