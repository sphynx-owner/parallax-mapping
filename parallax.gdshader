shader_type spatial;

// from https://learnopengl.com/Advanced-Lighting/Parallax-Mapping

uniform sampler2D diffuseMap : source_color, filter_linear_mipmap;
uniform sampler2D normalMap : source_color, filter_linear;
uniform sampler2D depthMap : source_color, filter_linear;

uniform float heightScale;

// number of depth layers
uniform float minLayers = 8.;
uniform float maxLayers = 32.;

void vertex() {
	// Called for every vertex the material is visible on.
}

vec2 ParallaxMapping(vec2 texCoords, vec3 viewDir, out float offset)
{ 
	float numLayers = mix(maxLayers, minLayers, abs(dot(vec3(0.0, 0.0, 1.0), viewDir)));  
	// calculate the size of each layer
	float layerDepth = 1.0 / numLayers;
	// depth of current layer
	float currentLayerDepth = 0.0;
	// the amount to shift the texture coordinates per layer (from vector P)
	vec2 P = viewDir.xy / viewDir.z * heightScale; 
	vec2 deltaTexCoords = P / numLayers;

	// get initial values
	vec2  currentTexCoords     = texCoords;
	float currentDepthMapValue = texture(depthMap, currentTexCoords).r;
	    
	while(currentLayerDepth < currentDepthMapValue)
	{
	    // shift texture coordinates along direction of P
	    currentTexCoords -= deltaTexCoords;
	    // get depthmap value at current texture coordinates
	    currentDepthMapValue = texture(depthMap, currentTexCoords).r;  
	    // get depth of next layer
	    currentLayerDepth += layerDepth;  
	}

	// get texture coordinates before collision (reverse operations)
	vec2 prevTexCoords = currentTexCoords + deltaTexCoords;

	// get depth after and before collision for linear interpolation
	float afterDepth  = currentDepthMapValue - currentLayerDepth;
	float beforeDepth = texture(depthMap, prevTexCoords).r - currentLayerDepth + layerDepth;

	// interpolation of texture coordinates
	float weight = afterDepth / (afterDepth - beforeDepth);
	vec2 finalTexCoords = prevTexCoords * weight + currentTexCoords * (1.0 - weight);
	
	offset = currentLayerDepth / abs(dot(vec3(0.0, 0.0, 1.0), viewDir)) * heightScale;
	
	return finalTexCoords;
}

void fragment()
{           
	// offset texture coordinates with Parallax Mapping
	vec3 world_vertex = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mat3 tangent_basis = mat3(
	TANGENT,
	-BINORMAL,
	NORMAL);
	
	vec3 viewDir = transpose(mat3(INV_VIEW_MATRIX) * tangent_basis) * normalize(CAMERA_POSITION_WORLD - world_vertex);
	vec2 texCoords = UV;
	float offset;
	texCoords = ParallaxMapping(UV,  viewDir, offset);       
	if(texCoords.x > 1.0 || texCoords.y > 1.0 || texCoords.x < 0.0 || texCoords.y < 0.0)
	    discard;

	NORMAL_MAP = ((texture(normalMap, texCoords).rgb * 2. - 1.) * vec3(1, -1, 1) + 1.) / 2.;
	//NORMAL_MAP_DEPTH = 2.;   

	// get diffuse color
	ALBEDO = texture(diffuseMap, texCoords).rgb;
	
	LIGHT_VERTEX.z -= offset;
	
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2. - 1., FRAGCOORD.z, 1.0);
	view_position.xyz /= view_position.w;
	
	view_position.z -= offset;
	
	vec4 ndc_position = PROJECTION_MATRIX * vec4(view_position.xyz, 1.0);
	ndc_position.xyz /= ndc_position.w;
	
	DEPTH = ndc_position.z;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
