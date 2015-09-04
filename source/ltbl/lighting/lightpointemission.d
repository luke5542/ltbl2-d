module ltbl.lighting.lightpointemission;

import ltbl;

import dsfml.graphics;

private struct OuterEdges {
    int[] outerBoundaryIndices;
    Vector2f[] outerBoundaryVectors;
}

class LightPointEmission : QuadtreeOccupant {

    public
    {
        Sprite emissionSprite;
        Vector2f localCastCenter;

        float sourceRadius;
        float shadowOverExtendMultiplier;
    }

    this()
    {
        emissionSprite = new Sprite();
        localCastCenter = Vector2f(0.0f, 0.0f);
        sourceRadius = 8.0f;
        shadowOverExtendMultiplier = 1.4f;
    }

    override FloatRect getAABB() {
        return emissionSprite.getGlobalBounds();
    }

    void render(ref const(View) view, ref RenderTexture lightTempTexture,
                ref RenderTexture emissionTempTexture,
                ref RenderTexture antumbraTempTexture,
                ref const(QuadtreeOccupant[]) shapes,
                ref Shader unshadowShader, ref Shader lightOverShapeShader)
    {
        LightSystem.clear(emissionTempTexture, Color.Black);

        emissionTempTexture.view = view;
        emissionTempTexture.draw(emissionSprite);
        emissionTempTexture.display();

        LightSystem.clear(lightTempTexture, Color.Black);

        lightTempTexture.view = view;

        lightTempTexture.draw(emissionSprite);

        Transform t;
        t.translate(emissionSprite.position.x, emissionSprite.position.y);
        t.rotate(emissionSprite.rotation);
        t.scale(emissionSprite.scale.x, emissionSprite.scale.y);

        Vector2f castCenter = t.transformPoint(localCastCenter);

        float shadowExtension = shadowOverExtendMultiplier * (getAABB().width + getAABB().height);

        OuterEdges[] outerEdges = new OuterEdges[shapes.length];

        // Mask off light shape (over-masking - mask too much, reveal penumbra/antumbra afterwards)
        for (int i = 0; i < shapes.length; i++)
        {
            LightShape lightShape = cast(LightShape) shapes[i];

            // Get boundaries
            int[] innerBoundaryIndices;
            Vector2f[] innerBoundaryVectors;
            LightSystem.Penumbra[] penumbras;

            LightSystem.getPenumbrasPoint(penumbras, innerBoundaryIndices,
                innerBoundaryVectors, outerEdges[i].outerBoundaryIndices,
                outerEdges[i].outerBoundaryVectors, lightShape.shape,
                castCenter, sourceRadius);

            if (innerBoundaryIndices.length != 2 || outerEdges[i].outerBoundaryIndices.length != 2)
                continue;

            // Render shape
            if (!lightShape.renderLightOverShape)
            {
                lightShape.shape.fillColor = Color.Black;

                lightTempTexture.draw(lightShape.shape);
            }

            RenderStates maskRenderStates;
            maskRenderStates.blendMode = BlendMode.None;

            Vector2f as = lightShape.shape.getTransform().transformPoint(lightShape.shape.getPoint(outerEdges[i].outerBoundaryIndices[0]));
            Vector2f bs = lightShape.shape.getTransform().transformPoint(lightShape.shape.getPoint(outerEdges[i].outerBoundaryIndices[1]));
            Vector2f ad = outerEdges[i].outerBoundaryVectors[0];
            Vector2f bd = outerEdges[i].outerBoundaryVectors[1];

            Vector2f intersectionOuter;

            // Handle antumbras as a seperate case
            if (rayIntersect(as, ad, bs, bd, intersectionOuter))
            {
                Vector2f asi = lightShape.shape.getTransform().transformPoint(lightShape.shape.getPoint(innerBoundaryIndices[0]));
                Vector2f bsi = lightShape.shape.getTransform().transformPoint(lightShape.shape.getPoint(innerBoundaryIndices[1]));
                Vector2f adi = innerBoundaryVectors[0];
                Vector2f bdi = innerBoundaryVectors[1];

                LightSystem.clear(antumbraTempTexture, Color.White);

                antumbraTempTexture.view = view;

                Vector2f intersectionInner;

                if (rayIntersect(asi, adi, bsi, bdi, intersectionInner))
                {
                    ConvexShape maskShape = new ConvexShape();

                    maskShape.pointCount = 3;

                    maskShape.setPoint(0, asi);
                    maskShape.setPoint(1, bsi);
                    maskShape.setPoint(2, intersectionInner);

                    maskShape.fillColor = Color.Black;

                    antumbraTempTexture.draw(maskShape);
                }
                else
                {
                    ConvexShape maskShape = new ConvexShape();

                    maskShape.pointCount = 4;

                    maskShape.setPoint(0, asi);
                    maskShape.setPoint(1, bsi);
                    maskShape.setPoint(2, bsi + vectorNormalize(bdi) * shadowExtension);
                    maskShape.setPoint(3, asi + vectorNormalize(adi) * shadowExtension);

                    maskShape.fillColor = Color.Black;

                    antumbraTempTexture.draw(maskShape);
                }

                // Add light back for antumbra/penumbras
                VertexArray vertexArray = new VertexArray(PrimitiveType.Triangles, 3);

                RenderStates penumbraRenderStates;
                penumbraRenderStates.blendMode = BlendMode.Add;
                penumbraRenderStates.shader = unshadowShader;

                // Unmask with penumbras
                for (int j = 0; j < penumbras.length; j++)
                {
                    unshadowShader.setParameter("lightBrightness", penumbras[j].lightBrightness);
                    unshadowShader.setParameter("darkBrightness", penumbras[j].darkBrightness);

                    vertexArray[0].position = penumbras[j].source;
                    vertexArray[1].position = penumbras[j].source + vectorNormalize(penumbras[j].lightEdge) * shadowExtension;
                    vertexArray[2].position = penumbras[j].source + vectorNormalize(penumbras[j].darkEdge) * shadowExtension;

                    vertexArray[0].texCoords = Vector2f(0.0f, 1.0f);
                    vertexArray[1].texCoords = Vector2f(1.0f, 0.0f);
                    vertexArray[2].texCoords = Vector2f(0.0f, 0.0f);

                    antumbraTempTexture.draw(vertexArray, penumbraRenderStates);
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
            else
            {
                ConvexShape maskShape = new ConvexShape();

                maskShape.pointCount = 4;

                maskShape.setPoint(0, as);
                maskShape.setPoint(1, bs);
                maskShape.setPoint(2, bs + vectorNormalize(bd) * shadowExtension);
                maskShape.setPoint(3, as + vectorNormalize(ad) * shadowExtension);

                maskShape.fillColor = Color.Black;

                lightTempTexture.draw(maskShape);

                VertexArray vertexArray = new VertexArray(PrimitiveType.Triangles, 3);

                RenderStates penumbraRenderStates;
                penumbraRenderStates.blendMode = BlendMode.Multiply;
                penumbraRenderStates.shader = unshadowShader;

                // Unmask with penumbras
                for (int j = 0; j < penumbras.length; j++)
                {
                    unshadowShader.setParameter("lightBrightness", penumbras[j].lightBrightness);
                    unshadowShader.setParameter("darkBrightness", penumbras[j].darkBrightness);

                    vertexArray[0].position = penumbras[j].source;
                    vertexArray[1].position = penumbras[j].source + vectorNormalize(penumbras[j].lightEdge) * shadowExtension;
                    vertexArray[2].position = penumbras[j].source + vectorNormalize(penumbras[j].darkEdge) * shadowExtension;

                    vertexArray[0].texCoords = Vector2f(0.0f, 1.0f);
                    vertexArray[1].texCoords = Vector2f(1.0f, 0.0f);
                    vertexArray[2].texCoords = Vector2f(0.0f, 0.0f);

                    lightTempTexture.draw(vertexArray, penumbraRenderStates);
                }
            }
        }

        for (int i = 0; i < shapes.length; i++)
        {
            LightShape lightShape = cast(LightShape) shapes[i];

            if (lightShape.renderLightOverShape)
            {
                lightShape.shape.fillColor = Color.White;

                auto states = RenderStates.Default;
                states.shader = lightOverShapeShader;
                lightTempTexture.draw(lightShape.shape, states);
            }
            else
            {
                lightShape.shape.fillColor = Color.Black;

                lightTempTexture.draw(lightShape.shape);
            }
        }

        lightTempTexture.display();
    }

}
