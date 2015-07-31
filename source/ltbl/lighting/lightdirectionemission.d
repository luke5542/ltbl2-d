module ltbl.lighting.lightdirectionemission;

import dsfml.graphics;
import ltbl.quadtree.quadtreeoccupant;

class LightDirectionEmission {

    public
    {
        Sprite emissionSprite;
        Vector2f castDirection;

        float sourceRadius;
        float sourceDistance;
    }

    LightDirectionEmission()
    {
        emissionSprite = new Sprite();
        castDirection = Vector2f(0.0f, 1.0f);
        sourceRadius = 5.0f;
        sourceDistance = 100.0f;
    }

    void render(const ref View view, ref RenderTexture lightTempTexture,
                ref RenderTexture antumbraTempTexture,
                const QuadtreeOccupant[] shapes,
                ref Shader unshadowShader, float shadowExtension)
    {
        lightTempTexture.setView(view);

        LightSystem::clear(lightTempTexture, Color::White);

        // Mask off light shape (over-masking - mask too much, reveal penumbra/antumbra afterwards)
        for (int i = 0; i < shapes.size(); i++) {
            LightShape* lightShape = static_cast<LightShape*>(shapes[i]);

            // Get boundaries
            LightSystem::Penumbra[] penumbras;
            int[] innerBoundaryIndices;
            int[] outerBoundaryIndices;
            Vector2f[] innerBoundaryVectors;
            Vector2f[] outerBoundaryVectors;

            LightSystem::getPenumbrasDirection(penumbras, innerBoundaryIndices, innerBoundaryVectors, outerBoundaryIndices, outerBoundaryVectors, lightShape._shape, castDirection, sourceRadius, sourceDistance);

            if (innerBoundaryIndices.size() != 2 || outerBoundaryIndices.size() != 2)
                continue;

            LightSystem::clear(antumbraTempTexture, Color::White);

            antumbraTempTexture.setView(view);

            ConvexShape maskShape;

            float maxDist = 0.0f;

            for (int j = 0; j < lightShape._shape.getPointCount(); j++)
                maxDist = std::max(maxDist, vectorMagnitude(view.getCenter() - lightShape._shape.getTransform().transformPoint(lightShape._shape.getPoint(j))));

            float totalShadowExtension = shadowExtension + maxDist;

            maskShape.setPointCount(4);

            maskShape.setPoint(0, lightShape._shape.getTransform().transformPoint(lightShape._shape.getPoint(innerBoundaryIndices[0])));
            maskShape.setPoint(1, lightShape._shape.getTransform().transformPoint(lightShape._shape.getPoint(innerBoundaryIndices[1])));
            maskShape.setPoint(2, lightShape._shape.getTransform().transformPoint(lightShape._shape.getPoint(innerBoundaryIndices[1])) + vectorNormalize(innerBoundaryVectors[1]) * totalShadowExtension);
            maskShape.setPoint(3, lightShape._shape.getTransform().transformPoint(lightShape._shape.getPoint(innerBoundaryIndices[0])) + vectorNormalize(innerBoundaryVectors[0]) * totalShadowExtension);

            maskShape.setFillColor(Color::Black);

            antumbraTempTexture.draw(maskShape);

            VertexArray vertexArray;

            vertexArray.setPrimitiveType(PrimitiveType::Triangles);

            vertexArray.resize(3);

            {
                RenderStates states;
                states.blendMode = BlendAdd;
                states.shader = &unshadowShader;

                // Unmask with penumbras
                for (int j = 0; j < penumbras.size(); j++) {
                    unshadowShader.setParameter("lightBrightness", penumbras[j]._lightBrightness);
                    unshadowShader.setParameter("darkBrightness", penumbras[j]._darkBrightness);

                    vertexArray[0].position = penumbras[j]._source;
                    vertexArray[1].position = penumbras[j]._source + vectorNormalize(penumbras[j]._lightEdge) * totalShadowExtension;
                    vertexArray[2].position = penumbras[j]._source + vectorNormalize(penumbras[j]._darkEdge) * totalShadowExtension;

                    vertexArray[0].texCoords = Vector2f(0.0f, 1.0f);
                    vertexArray[1].texCoords = Vector2f(1.0f, 0.0f);
                    vertexArray[2].texCoords = Vector2f(0.0f, 0.0f);

                    antumbraTempTexture.draw(vertexArray, states);
                }
            }

            antumbraTempTexture.display();

            // Multiply back to lightTempTexture
            RenderStates antumbraRenderStates;
            antumbraRenderStates.blendMode = BlendMultiply;

            Sprite s;

            s.setTexture(antumbraTempTexture.getTexture());

            lightTempTexture.setView(lightTempTexture.getDefaultView());

            lightTempTexture.draw(s, antumbraRenderStates);

            lightTempTexture.setView(view);
        }

        for (int i = 0; i < shapes.size(); i++) {
            LightShape* lightShape = static_cast<LightShape*>(shapes[i]);

            if (lightShape._renderLightOverShape) {
                lightShape._shape.setFillColor(Color::White);

                lightTempTexture.draw(lightShape._shape);
            }
        }

        // Multiplicatively blend the light over the shadows
        RenderStates lightRenderStates;
        lightRenderStates.blendMode = BlendMultiply;

        lightTempTexture.setView(lightTempTexture.getDefaultView());

        lightTempTexture.draw(emissionSprite, lightRenderStates);

        lightTempTexture.display();
    }
}
