Shader "Okaeri/VFX/AnimeParticle"
{
	Properties
	{
		_EmissionTex("Emissive", 2D) = "white" {}
		_NoiseTex("Noise", 2D) = "white" {}
		_FlowTex("Flow", 2D) = "white" {}
		_MaskTex("Mask", 2D) = "white" {}
		_Speed("Speed (Emi XY Noise ZW)", Vector) = (0,0,0,0)
		_Distortion("Distortion (Spd XY Pwr Z)", Vector) = (0,0,0,0)
		_Emissive("Emission", Range(0, 10)) = 2
		_Color("Colour Shift", Color) = (0.5,0.5,0.5,1)
		_Opacity("Opacity", Range( 0, 3)) = 1
		[Toggle]_Bloom("Bloom", Float) = 0
		[Toggle]_SoftParticle("Soft Particle", Float) = 0
		[Enum(Cull Off,0, Cull Front,1, Cull Back,2)] _CullMode("Culling", Float) = 0
	}

	Category
	{
		SubShader
		{
			Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "VRCFallback" = "Hidden" "PreviewType" = "Plane" }
			LOD 100
			Cull[_CullMode]
			Lighting Off
			ZWrite Off
			ZTest LEqual
			ColorMask RGB
			Blend SrcAlpha OneMinusSrcAlpha
			
			Pass {
				CGPROGRAM
				
				#ifndef UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX
				#define UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input)
				#endif
				
				#pragma vertex vert
				#pragma fragment frag
				#pragma target 3.0

				#pragma multi_compile_particles

				#include "UnityShaderVariables.cginc"
				#include "UnityCG.cginc"

				uniform sampler2D _EmissionTex;
				uniform float4 _EmissionTex_ST;
				uniform sampler2D _FlowTex;
				uniform float4 _FlowTex_ST;
				uniform sampler2D _MaskTex;
				uniform float4 _MaskTex_ST;
				uniform sampler2D _NoiseTex;
				uniform float4 _NoiseTex_ST;
				uniform float4 _Color;
				uniform float _Emissive;
				uniform float _Opacity;
				uniform float _Bloom;
				uniform float4 _Distortion;
				uniform float4 _Speed;
				uniform half _SoftParticle;

				struct appdata_t
				{
					fixed4 color : COLOR;
					float4 vertex : POSITION;
					float4 texcoord : TEXCOORD0;

					UNITY_VERTEX_INPUT_INSTANCE_ID
				};

				struct v2f
				{
					fixed4 color : COLOR;
					float4 pos : SV_POSITION;
					float4 texcoord : TEXCOORD0;

					#ifdef SOFTPARTICLES_ON
					float4 projPos : TEXCOORD2;
					#endif

					UNITY_VERTEX_OUTPUT_STEREO	
				};
				
				UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
				//uniform sampler2D _CameraDepthTexture; //OLD

				v2f vert (appdata_t v)
				{
					v2f o;

					UNITY_SETUP_INSTANCE_ID(v);
					UNITY_INITIALIZE_OUTPUT(v2f, o);
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
					
					o.pos = UnityObjectToClipPos(v.vertex);

					#ifdef SOFTPARTICLES_ON
						o.projPos = ComputeScreenPos (o.pos);
						COMPUTE_EYEDEPTH(o.projPos.z);
					#endif

					o.color = v.color;
					o.texcoord = v.texcoord;

					return o;
				}

				fixed4 frag (v2f i) : SV_Target
				{
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
				
					#ifdef SOFTPARTICLES_ON
					half sceneZ = 0;
					half partZ = 0;
					half fade = 0;

					if (_SoftParticle == 1)
					{
						sceneZ = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
						partZ = i.projPos.z;
						fade = saturate(sceneZ - partZ);
						i.color.a *= fade;
					}
					#endif

					half2 uvEmi = TRANSFORM_TEX(i.texcoord, _EmissionTex);
					half2 uvMask = TRANSFORM_TEX(i.texcoord, _MaskTex);
					half2 uvNoise = TRANSFORM_TEX(i.texcoord, _NoiseTex);
					half2 uvFlow = TRANSFORM_TEX(i.texcoord, _FlowTex);

					half2 speedEmi = _Time.y * half2(_Speed.x, _Speed.y) + uvEmi;
					half2 distortionSpd = _Time.y * half2(_Distortion.x, _Distortion.y) + uvFlow;
					half2 speedNoise = _Time.y * half2(_Speed.z, _Speed.w) + uvNoise;

					half4 mask = tex2D(_MaskTex, uvMask);
					half4 emission = tex2D(_EmissionTex, speedEmi - tex2D(_FlowTex, distortionSpd).rg * mask * _Distortion.z);
					half4 noise = tex2D(_NoiseTex, speedNoise);

					half3 rgb = emission * noise * _Color * i.color.rgb;
					half4 clamped = saturate(mask * (mask - (1.0 - i.texcoord.z).xxxx));

					half4 c = (half4((lerp(rgb, (rgb * clamped.rgb ), _Bloom) * _Emissive) , (emission.a * noise.a * _Color.a * i.color.a * _Opacity)));

					return c;
				}
				ENDCG 
			}
		}
	}
	Fallback Off
}