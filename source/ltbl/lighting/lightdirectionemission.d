module ltbl.lighting.lightdirectionemission;

import ltbl;

import dsfml.graphics;

import std.math;

class LightDirectionEmission {

    public
    {
        Sprite emissionSprite;
        Vector2f castDirection;

        float sourceRadius;
        float sourceDistance;
    }

    this()
    {
        emissionSprite = new Sprite();
        castDirection = Vector2f(0.0f, 1.0f);
        sourceRadius = 5.0f;
        sourceDistance = 100.0f;
    }

    void render(ref const(View) view, ref RenderTexture lightTempTexture,
                ref RenderTexture antumbraTempTexture,
                const(QuadtreeOccupant[]) shapes,
                ref Shader unshadowShader, float shadowExtension)
    {
        lightTempTexture.view = view;

        LightSystem.clear(lightTempTexture, Color.White);

        // Mask off light shape (over-masking - mask too much, reveal penumbra/antumbra afterwards)
        for (int i = 0; i < shapes.length; i++) {
            LightShape lightShape = cast(LightShape) shapes[i];

            // Get boundaries
            LightSystem.Penumbra[] penumbras;
            int[] innerBoundaryIndices;
            int[] outerBoundaryIndices;
            Vector2f[] innerBoundaryVectors;
            Vector2f[] outerBoundaryVectors;

            LightSystem.getPenumbrasDirection(penumbras, innerBoundaryIndices,
                        innerBoundaryVectors, outerBoundaryIndices, outerBoundaryVectors,
                        lightShape.shape, castDirection, sourceRadius, sourceDistance);

            if (innerBoundaryIndices.length != 2 || outerBoundaryIndices.length != 2)
                continue;

            LightSystem.clear(antumbraTempTexture, Color.White);

            antumbraTempTexture.view = view;

            ConvexShape maskShape;

            float maxDist = 0.0f;

            for (int j = 0; j < lightShape.shape.pointCount; j++)
                maxDist = fmax(maxDist, vectorMagnitude(view.center - lightShape.shape.getTransform().transformPoint(lightShape.shape.getPoint(j))));

            float totalShadowExtension = shadowExtension + maxDist;

            maskShape.pointCount = 4;

            maskShape.setPoint(0, lightShape.shape.getTransform().transformPoint(lightShape.shape.getPoint(innerBoundaryIndices[0])));
            maskShape.setPoint(1, lightShape.shape.getTransform().transformPoint(lightShape.shape.getPoint(innerBoundaryIndices[1])));
            maskShape.setPoint(2, lightShape.shape.getTransform().transformPoint(lightShape.shape.getPoint(innerBoundaryIndices[1])) + vectorNormalize(innerBoundaryVectors[1]) * totalShadowExtension);
            maskShape.setPoint(3, lightShape.shape.getTransform().transformPoint(lightShape.shape.getPoint(innerBoundaryIndices[0])) + vectorNormalize(innerBoundaryVectors[0]) * totalShadowExtension);

            maskShape.fillColor = Color.Black;

            antumbraTempTexture.draw(maskShape);

            VertexArray vertexArray;

            vertexArray.primitiveType = PrimitiveType.Triangles;

            vertexArray.resize(3);

            {
                RenderStates states;
                states.blendMode = BlendMode.Add;
                states.shader = unshadowShader;

                // Unmask with penumbras
                for (int j = 0; j < penumbras.length; j++) {
                    unshadowShader.setParameter("lightBrightness", penumbras[j].lightBrightness);
                    unshadowShader.setParameter("darkBrightness", penumbras[j].darkBrightness);

                    vertexArray[0].position = penumbras[j].source;
                    vertexArray[1].position = penumbras[j].source + vectorNormalize(penumbras[j].lightEdge) * totalShadowExtension;
                    vertexArray[2].position = penumbras[j].source + vectorNormalize(penumbras[j].darkEdge) * totalShadowExtension;

                    vertexArray[0].texCoords = Vector2f(0.0f, 1.0f);
                    vertexArray[1].texCoords = Vector2f(1.0f, 0.0f);
                    vertexArray[2].texCoords = Vector2f(0.0f, 0.0f);

                    antumbraTempTexture.draw(vertexArray, states);
                }
            }

            antumbraTempTexture.display();

            // Multiply back to lightTempTexture
            RenderStates antumbraRenderStates;
            antumbraRenderStates.blendMode = BlendMode.Multiply;

            Sprite s = new Sprite();

            s.setTexture(antumbraTempTexture.getTexture());

            lightTempTexture.view = lightTempTexture.getDefaultView();

            lightTempTexture.draw(s, antumbraRenderStates);

            lightTempTexture.view = view;
        }

        for(int i = 0; i < shapes.length; i++) {
            LightShape lightShape = cast(LightShape) shapes[i];

            if (lightShape.renderLightOverShape) {
                lightShape.shape.fillColor = Color.White;

                lightTempTexture.draw(lightShape.shape);
            }
        }

        // Multiplicatively blend the light over the shadows
        RenderStates lightRenderStates;
        lightRenderStates.blendMode = BlendMode.Multiply;

        lightTempTexture.view = lightTempTexture.getDefaultView();

        lightTempTexture.draw(emissionSprite, lightRenderStates);

        lightTempTexture.display();
    }
}
