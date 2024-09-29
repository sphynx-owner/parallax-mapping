shader_type spatial;

// from https://learnopengl.com/Advanced-Lighting/Parallax-Mapping

uniform sampler2D diffuseMap : source_color, filter_linear_mipmap;
uniform sampler2D normalMap : source_color, filter_linear;
uniform sampler2D depthMap : source_color, filter_linear;

uniform float heightScale;

// number of depth layers
uniform float minLayers = 8.;
uniform float maxLayers = 32.;

uniform bool inverse_height = false;
uniform bool compressed_normals = true;

uniform vec2 texture_scale = vec2(1.0);

uniform bool discard_edge = true;

void vertex() {
	// Called for every vertex the material is visible on.
}

vec4 get_diffuse(vec2 uv) {
	return texture(diffuseMap, uv * texture_scale);
}

float get_height(vec2 uv) {
	return inverse_height ? 1. - texture(depthMap, uv * texture_scale).r : texture(depthMap, uv * texture_scale).r;
}

vec3 get_normal(vec2 uv) {
	return compressed_normals ? ((texture(normalMap, uv * texture_scale).rgb * 2. - 1.) * vec3(1, -1, 1) + 1.) / 2. : texture(normalMap, uv * texture_scale).rgb;
}

vec2 ParallaxMapping(vec2 texCoords, vec3 tangent_view_dir, out float offset)
{ 
	float numLayers = mix(maxLayers, minLayers, abs(dot(vec3(0.0, 0.0, 1.0), tangent_view_dir)));  
	// calculate the size of each layer
	float layerDepth = 1.0 / numLayers;
	// depth of current layer
	float currentLayerDepth = 0.0;
	// the amount to shift the texture coordinates per layer (from vector P)
	vec2 P = tangent_view_dir.xy / tangent_view_dir.z * heightScale; 
	vec2 deltaTexCoords = P / numLayers;

	// get initial values
	vec2  currentTexCoords     = texCoords;
	float currentDepthMapValue = get_height(currentTexCoords);
	    
	while(currentLayerDepth < currentDepthMapValue)
	{
	    // shift texture coordinates along direction of P
	    currentTexCoords -= deltaTexCoords;
	    // get depthmap value at current texture coordinates
	    currentDepthMapValue = get_height(currentTexCoords);  
	    // get depth of next layer
	    currentLayerDepth += layerDepth;  
	}

	// get texture coordinates before collision (reverse operations)
	vec2 prevTexCoords = currentTexCoords + deltaTexCoords;

	// get depth after and before collision for linear interpolation
	float afterDepth  = currentDepthMapValue - currentLayerDepth;
	float beforeDepth = get_height(prevTexCoords) - currentLayerDepth + layerDepth;

	// interpolation of texture coordinates
	float weight = afterDepth / (afterDepth - beforeDepth);
	vec2 finalTexCoords = prevTexCoords * weight + currentTexCoords * (1.0 - weight);
	
	offset = currentLayerDepth / abs(dot(vec3(0.0, 0.0, 1.0), tangent_view_dir)) * heightScale;
	
	return finalTexCoords;
}

void fragment()
{           
	vec4 view_ray_origin = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2. - 1., 1., 1.0);
	view_ray_origin.xyz /= view_ray_origin.w;
	
	vec3 view_direction = normalize(view_ray_origin.xyz - VERTEX);
	
	mat3 tangent_basis = mat3(
	TANGENT,
	-BINORMAL,
	NORMAL);
	
	vec3 tangent_view_dir = transpose(tangent_basis) * view_direction;
	vec2 texCoords = UV;
	float offset;
	texCoords = ParallaxMapping(UV, tangent_view_dir, offset);       
	
	if(discard_edge && (texCoords.x > 1.0 || texCoords.y > 1.0 || texCoords.x < 0.0 || texCoords.y < 0.0))
	    discard;
	
	NORMAL_MAP =  get_normal(texCoords);
	NORMAL_MAP_DEPTH = 2.;   

	// get diffuse color
	ALBEDO = get_diffuse(texCoords).rgb;
	
	LIGHT_VERTEX -= offset * view_direction;
	
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2. - 1., FRAGCOORD.z, 1.0);
	view_position.xyz /= view_position.w;
	
	view_position.xyz -= offset * view_direction;
	
	vec4 ndc_position = PROJECTION_MATRIX * vec4(view_position.xyz, 1.0);
	ndc_position.xyz /= ndc_position.w;
	
	DEPTH = ndc_position.z;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
