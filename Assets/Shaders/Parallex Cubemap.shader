Shader "Unlit/Parallex Cubemap"
{
    Properties
    {
        _mainCube("MainCube", Cube) = "" {}
        [Toggle(_isWorld)]
        _isWorldSpace("World Space Toggle", float) = 1

        [Header(Display Axis)]
        [KeywordEnum(XAxis, YAxis, ZAxis)] 
        _selectAxis("Selected Axis", float) = 1
        _xCubeScale("X Scale", Range(0,2)) = 1
        _yCubeScale("Y Scale", Range(0,2)) = 1
        _zCubeScale("Z Sclae", Range(0,2)) = 1
        _CubeOffset("Cube Offset", Vector) = (0,0,0,1)

        // _radiusVector("Radius", float) = 5
    }
    SubShader
    {
        Tags{"RenderType"="Opaque"}

        Pass
        {
            Tags{"LightMode"="ForwardBase"}

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase

            #pragma multi_compile _isWorld _
            //choose
            #pragma multi_compile _SELECTAXIS_XAXIS _SELECTAXIS_YAXIS _SELECTAXIS_ZAXIS
            

            #include "UnityCG.cginc"

            #define MESH_STANDARD_RADIUS 5.0f

            struct v2f
            {
                float4 pos : SV_POSITION;
				// float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float3 worldViewDir : TEXCOORD2;
                float3 objectPos : TEXCOORD3;
                float3 objectViewDir : TEXCOORD4;
            };

            //cube orign position
            struct cubeAxisPosition
            {
                float3 nxRP;
                float3 xRP;
                float3 nyRP;
                float3 yRP;
                float3 nzRP;
                float3 zRP;
                float3 centerPos;
            };
            
            //cube normal along axis
            struct cubeNormal
            {
                float3 nxNormal;
                float3 xNormal;
                float3 nyNormal;
                float3 yNormal;
                float3 nzNormal;
                float3 zNormal;
            };

            samplerCUBE _mainCube;
            // float _isWorldSpace;
            float _xCubeScale;
            float _yCubeScale;
            float _zCubeScale;
            float4 _CubeOffset;
            // float _radiusVector;

            //caculate intersect point with specific plane
            float3 CalculateIntersectPoint (float3 linePoint , float3 lineDIr ,float3 planePoint , float3 planeNormal )
            {
                float s = dot((planePoint - linePoint) , planeNormal) / dot(lineDIr , planeNormal) ;
                float3 p0 = s * normalize(lineDIr) + linePoint ;
                return p0;
            }

            float3 CubeOrientMask(float3 intersectPoint, float3 centerPos, float axisType, float radius)
            {
                // half3 intersectP = CalculateIntersectPoint(i.worldPos, worldViewDir, p.nxRP, n.nxNormal);
                float3 UV = intersectPoint - centerPos;
                float3 UVHalf = floor(abs(UV / radius));
                float3 UVMask = 0;
                //x
                if (axisType == 1)
                    UVMask = 1 - saturate(max(UVHalf.y, UVHalf.z));
                //y
                if (axisType == 2)
                    UVMask = 1 - saturate(max(UVHalf.x, UVHalf.z));
                //z
                if (axisType == 3)
                    UVMask = 1 - saturate(max(UVHalf.x, UVHalf.y));
                float3 finalUV = UVMask * UV;
                return finalUV;
            }

            float getMeshRadius()
            {
                float3 worldScale = float3(
                    length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x)), // scale x axis
                    length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y)), // scale y axis
                    length(float3(unity_ObjectToWorld[0].z, unity_ObjectToWorld[1].z, unity_ObjectToWorld[2].z))  // scale z axis
                );
                float radius = max(max(worldScale.x, worldScale.y), worldScale.z) * MESH_STANDARD_RADIUS;
                return radius;
            }

            v2f vert(appdata_full v)
            {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                o.pos = UnityObjectToClipPos(v.vertex);
                // o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld,v.vertex).xyz;
				o.worldViewDir = UnityWorldSpaceViewDir(o.worldPos);
                o.objectPos = v.vertex;
                o.objectViewDir = ObjSpaceViewDir(v.vertex);
                return o;
            }

            half4 frag (v2f i) : SV_TARGET
            {
                // half3 worldNormal = normalize(i.worldNormal);
                // float3 worldPos = normalize(i.worldPos); //enable normalize worldPos will encountered distortion in center plane
            #ifdef _isWorld
                float3 compilePos = i.worldPos;
                float3 compileViewDir = normalize(i.worldViewDir);
				// float3 worldViewDir = normalize(i.worldViewDir);
            #else
                float3 compilePos = i.objectPos;
                float3 compileViewDir = normalize(i.objectViewDir);
            #endif
                float radius = getMeshRadius();
            //caculate radius point along axis
                cubeAxisPosition p;
                UNITY_INITIALIZE_OUTPUT(cubeAxisPosition, p);
                p.xRP  = float3(radius,0,0);
                p.nxRP = float3(-radius,0,0);
                p.yRP  = float3(0,radius*2,0);
                p.nyRP = float3(0,-radius*2,0);
                p.zRP  = float3(0,0,radius);
                p.nzRP = float3(0,0,-radius);
                p.centerPos = float3(0,-radius,0);

                cubeNormal n;
                UNITY_INITIALIZE_OUTPUT(cubeNormal, n);
                n.nxNormal = float3(1,0,0);
                n.nyNormal = float3(0,1,0);
                n.nzNormal = float3(0,0,1);
                n.xNormal  = float3(-1,0,0);
                n.yNormal  = float3(0,-1,0);
                n.zNormal  = float3(0,0,-1);
                
            //-x
                half3 nxintersectP = CalculateIntersectPoint(compilePos, compileViewDir, p.nxRP, n.nxNormal);
                float3 nxFinalUV = CubeOrientMask(nxintersectP, p.centerPos, 1, radius);
            //x
                half3 xintersectP = CalculateIntersectPoint(compilePos, compileViewDir, p.xRP, n.xNormal);
                float3 xFinalUV = CubeOrientMask(xintersectP, p.centerPos, 1, radius);
            //-z
                half3 nzintersectP = CalculateIntersectPoint(compilePos, compileViewDir, p.nzRP, n.nzNormal);
                float3 nzFinalUV = CubeOrientMask(nzintersectP, p.centerPos, 3, radius);
            //z
                half3 zintersectP = CalculateIntersectPoint(compilePos, compileViewDir, p.zRP, n.zNormal);
                float3 zFinalUV = CubeOrientMask(zintersectP, p.centerPos, 3, radius);
            //-y
                half3 nyintersectP = CalculateIntersectPoint(compilePos, compileViewDir, p.nyRP, n.nyNormal);
                float3 nyFinalUV = CubeOrientMask(nyintersectP, p.centerPos, 2, radius);
            //y 
                half3 yintersectP = CalculateIntersectPoint(compilePos,compileViewDir, p.yRP, n.yNormal);
                float3 yFinalUV = CubeOrientMask(yintersectP, p.centerPos, 2, radius);
                
                float3 finalUV = nxFinalUV + nzFinalUV + xFinalUV + zFinalUV + nyFinalUV;
                finalUV *= float3(_xCubeScale,_yCubeScale,_zCubeScale);
                finalUV = float3(finalUV.x + _CubeOffset.x, finalUV.y, finalUV.z + _CubeOffset.z);
                // float3 finalUV = float3(0,0,0);
            #ifdef _SELECTAXIS_YAXIS
                finalUV = float3(finalUV.x, finalUV.y, finalUV.z);
            #elif _SELECTAXIS_ZAXIS
                finalUV = float3(finalUV.x, finalUV.z, -finalUV.y);
            #elif _SELECTAXIS_XAXIS
                finalUV = float3(finalUV.y, -finalUV.x, finalUV.z);
            // #else
            //     return float4(1,1,1,1);
            #endif
            // float3 finalUV = compileViewDir;
                // finalUV = float3(finalUV.x, finalUV.z, -finalUV.y);
                
                //with mipmap
                // half3 reflection = texCUBE(_mainCube, finalUV);

                //without mipmap
                half3 reflection = texCUBElod(_mainCube, float4(finalUV, 0));

                return half4 (reflection, 1.0);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}