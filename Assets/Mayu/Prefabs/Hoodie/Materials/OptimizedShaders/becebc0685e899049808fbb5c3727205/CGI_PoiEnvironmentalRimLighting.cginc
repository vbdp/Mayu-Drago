#ifndef POI_ENVIRONMENTAL_RIM
    #define POI_ENVIRONMENTAL_RIM
    float _EnableEnvironmentalRim;
    float _RimEnviroBlur;
    float _RimEnviroMinBrightness;
    float _RimEnviroWidth;
    float _RimEnviroSharpness;
    float _RimEnviroIntensity;
    #if defined(PROP_RIMENVIROMASK) || !defined(OPTIMIZER_ENABLED)
        POI_TEXTURE_NOSAMPLER(_RimEnviroMask);
    #endif
    float3 calculateEnvironmentalRimLighting(in float4 albedo)
    {
        float enviroRimAlpha = saturate(1 - smoothstep(min((0.2 /*_RimEnviroSharpness*/), (0.6 /*_RimEnviroWidth*/)), (0.6 /*_RimEnviroWidth*/), poiCam.viewDotNormal));
        (0.7 /*_RimEnviroBlur*/) *= 1.7 - 0.7 * (0.7 /*_RimEnviroBlur*/);
        float3 enviroRimColor = 0;
        float interpolator = unity_SpecCube0_BoxMin.w;
        
        if (interpolator < 0.99999)
        {
            float4 reflectionData0 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, poiMesh.normals[1], (0.7 /*_RimEnviroBlur*/) * UNITY_SPECCUBE_LOD_STEPS);
            float3 reflectionColor0 = DecodeHDR(reflectionData0, unity_SpecCube0_HDR);
            float4 reflectionData1 = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, poiMesh.normals[1], (0.7 /*_RimEnviroBlur*/) * UNITY_SPECCUBE_LOD_STEPS);
            float3 reflectionColor1 = DecodeHDR(reflectionData1, unity_SpecCube1_HDR);
            enviroRimColor = lerp(reflectionColor1, reflectionColor0, interpolator);
        }
        else
        {
            float4 reflectionData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, poiMesh.normals[1], (0.7 /*_RimEnviroBlur*/) * UNITY_SPECCUBE_LOD_STEPS);
            enviroRimColor = DecodeHDR(reflectionData, unity_SpecCube0_HDR);
        }
        #if defined(PROP_RIMENVIROMASK) || !defined(OPTIMIZER_ENABLED)
            half enviroMask = poiMax(POI2D_SAMPLER_PAN(_RimEnviroMask, _MainTex, poiMesh.uv[(0.0 /*_RimEnviroMaskUV*/)], float4(0,0,0,0)).rgb);
        #else
            half enviroMask = 1;
        #endif
        return lerp(0, max(0, (enviroRimColor - (0.1 /*_RimEnviroMinBrightness*/)) * albedo.rgb), enviroRimAlpha).rgb * enviroMask * (0.25 /*_RimEnviroIntensity*/);
    }
#endif
