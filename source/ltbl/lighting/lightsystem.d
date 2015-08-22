module ltbl.lighting.lightsystem;

import ltbl.quadtree.dynamicquadtree.h;

import ltbl.lighting.lightpointemission.h;
import ltbl.lighting.lightdirectionemission.h;
import ltbl.lighting.lightshape.h;


struct Penumbra {
    Vector2f source;
    Vector2f lightEdge;
    Vector2f darkEdge;
    float lightBrightness;
    float darkBrightness;

    float distance;
};

class LightSystem {

    public
    {
        float directionEmissionRange;
        float directionEmissionRadiusMultiplier;
        Color ambientColor;
    }

    private
    {
        RenderTexture _lightTempTexture;
        RenderTexture _emissionTempTexture;
        RenderTexture _antumbraTempTexture;
        RenderTexture _compositionTexture;

        DynamicQuadtree _shapeQuadtree;
        DynamicQuadtree _lightPointEmissionQuadtree;

        LightPointEmission[] _pointEmissionLights;
        LightDirectionEmission[] _directionEmissionLights;
        LightShape[] _lightShapes;
    }

    LightSystem()
    {
        directionEmissionRange = 10_000.0;
        directionEmissionRadiusMultiplier = 1.1;
        ambientColor = Color(16, 16, 16);
    }

    void create(ref const(FloatRect) rootRegion,
                ref const(Vector2u) imageSize,
                ref const(Texture) penumbraTexture,
                ref Shader unshadowShader,
                ref Shader lightOverShapeShader)
    {
        _shapeQuadtree.create(rootRegion);
        _lightPointEmissionQuadtree.create(rootRegion);

        _lightTempTexture.create(imageSize.x, imageSize.y);
        _emissionTempTexture.create(imageSize.x, imageSize.y);
        _antumbraTempTexture.create(imageSize.x, imageSize.y);
        _compositionTexture.create(imageSize.x, imageSize.y);

        Vector2f targetSizeInv = Vector2f(1.0f / imageSize.x, 1.0f / imageSize.y);

        unshadowShader.setParameter("penumbraTexture", penumbraTexture);

        lightOverShapeShader.setParameter("emissionTexture", _emissionTempTexture.getTexture());
        lightOverShapeShader.setParameter("targetSizeInv", targetSizeInv);
    }

    void render(ref const(View) view, ref Shader unshadowShader,
                ref Shader lightOverShapeShader)
    {
        clear(_compositionTexture, ambientColor);
        _compositionTexture.setView(_compositionTexture.getDefaultView());

        // Get bounding rectangle of view
        FloatRect viewBounds = FloatRect(view.getCenter().x, view.getCenter().y, 0.0f, 0.0f);

        _lightTempTexture.setView(view);

        viewBounds = rectExpand(viewBounds, _lightTempTexture.mapPixelToCoords(Vector2i(0, 0)));
        viewBounds = rectExpand(viewBounds, _lightTempTexture.mapPixelToCoords(Vector2i(_lightTempTexture.getSize().x, 0)));
        viewBounds = rectExpand(viewBounds, _lightTempTexture.mapPixelToCoords(Vector2i(_lightTempTexture.getSize().x, _lightTempTexture.getSize().y)));
        viewBounds = rectExpand(viewBounds, _lightTempTexture.mapPixelToCoords(Vector2i(0, _lightTempTexture.getSize().y)));

        QuadtreeOccupant[] viewPointEmissionLights;

        _lightPointEmissionQuadtree.queryRegion(viewPointEmissionLights, viewBounds);

        for (int l = 0; l < viewPointEmissionLights.size(); l++) {
            LightPointEmission pointEmissionLight = viewPointEmissionLights[l];

            // Query shapes this light is affected by
            QuadtreeOccupant[] lightShapes;

            _shapeQuadtree.queryRegion(lightShapes, pointEmissionLight.getAABB());

            pointEmissionLight.render(view, _lightTempTexture, _emissionTempTexture,
                                        _antumbraTempTexture, lightShapes, unshadowShader,
                                        lightOverShapeShader);

            Sprite sprite = new Sprite(_lightTempTexture.getTexture());

            RenderStates compoRenderStates;
            compoRenderStates.blendMode = BlendMode.Add;

            _compositionTexture.draw(sprite, compoRenderStates);
        }

        for (emission; _directionEmissionLights) {
            LightDirectionEmission directionEmissionLight = emission.get();

            FloatRect centeredViewBounds = rectRecenter(viewBounds, Vector2f(0.0f, 0.0f));

            float maxDim = max(centeredViewBounds.width, centeredViewBounds.height);

            FloatRect extendedViewBounds = rectFromBounds(Vector2f(-maxDim, -maxDim) * directionEmissionRadiusMultiplier,
                Vector2f(maxDim, maxDim) * directionEmissionRadiusMultiplier + Vector2f(directionEmissionRange, 0.0f));

            float shadowExtension = vectorMagnitude(rectLowerBound(centeredViewBounds)) * directionEmissionRadiusMultiplier * 2.0f;

            ConvexShape directionShape = shapeFromRect(extendedViewBounds);
            directionShape.setPosition(view.getCenter());

            Vector2f normalizedCastDirection = vectorNormalize(directionEmissionLight._castDirection);

            directionShape.setRotation(_radToDeg * atan2(normalizedCastDirection.y, normalizedCastDirection.x));

            QuadtreeOccupant[] viewLightShapes;

            _shapeQuadtree.queryShape(viewLightShapes, directionShape);

            directionEmissionLight.render(view, _lightTempTexture, _antumbraTempTexture,
                                            viewLightShapes, unshadowShader, shadowExtension);

            Sprite sprite = new Sprite();
            sprite.setTexture(_lightTempTexture.getTexture());

            RenderStates compoRenderStates;
            compoRenderStates.blendMode = BlendMode.Add;

            _compositionTexture.draw(sprite, compoRenderStates);
        }

        _compositionTexture.display();
    }

    void addShape(ref const(LightShape) lightShape) {
        _shapeQuadtree.add(lightShape.get());

        _lightShapes.insert(lightShape);
    }

    void removeShape(ref const(LightShape) lightShape) {
        LightShape[] foundShapes = _lightShapes.find(lightShape);

        if (foundShapes.length > 1) {
            lightShape.quadtreeRemove();

            _lightShapes.erase(it);
        }
    }

    void addLight(ref const(LightPointEmission) pointEmissionLight) {
        _lightPointEmissionQuadtree.add(pointEmissionLight.get());

        _pointEmissionLights.insert(pointEmissionLight);
    }

    void addLight(ref const(LightDirectionEmission) directionEmissionLight) {
        _directionEmissionLights.insert(directionEmissionLight);
    }

    void removeLight(ref const(LightPointEmission) pointEmissionLight) {
        LightPointEmission[] emissions = _pointEmissionLights.find(pointEmissionLight);

        if (emissions.length > 1) {
            pointEmissionLight.quadtreeRemove();

            _pointEmissionLights.erase(it);
        }
    }

    void removeLight(ref const(LightDirectionEmission) directionEmissionLight) {
        auto emissionLight = _directionEmissionLights.find(directionEmissionLight);

        if (emissionLight !is null)
            _directionEmissionLights.erase(it);
    }


    void trimLightPointEmissionQuadtree() {
        _lightPointEmissionQuadtree.trim();
    }

    void trimShapeQuadtree() {
        _shapeQuadtree.trim();
    }

    const(Texture) getLightingTexture() const {
        return _compositionTexture.getTexture();
    }


private:
    static void getPenumbrasPoint(Penumbra[] penumbras,
                int[] innerBoundaryIndices,
                Vector2f[] innerBoundaryVectors,
                int[] outerBoundaryIndices,
                Vector2f[] outerBoundaryVectors,
                const(ConvexShape) shape,
                const(Vector2f) sourceCenter, float sourceRadius)
    {
        const int numPoints = shape.getPointCount();

        bool[] bothEdgesBoundaryWindings = new bool[2];

        bool[] oneEdgeBoundaryWindings = new bool[2];

        // Calculate front and back facing sides
        bool[] facingFrontBothEdges = new bool[numPoints];

        bool[] facingFrontOneEdge = new bool[numPoints];

        for (int i = 0; i < numPoints; i++)
        {
            Vector2f point = shape.getTransform().transformPoint(shape.getPoint(i));

            Vector2f nextPoint;

            if (i < numPoints - 1)
                nextPoint = shape.getTransform().transformPoint(shape.getPoint(i + 1));
            else
                nextPoint = shape.getTransform().transformPoint(shape.getPoint(0));

            Vector2f firstEdgeRay;
            Vector2f secondEdgeRay;
            Vector2f firstNextEdgeRay;
            Vector2f secondNextEdgeRay;

            {
                Vector2f sourceToPoint = point - sourceCenter;

                Vector2f perpendicularOffset = Vector2f(-sourceToPoint.y, sourceToPoint.x);

                perpendicularOffset = vectorNormalize(perpendicularOffset);
                perpendicularOffset *= sourceRadius;

                firstEdgeRay = point - (sourceCenter - perpendicularOffset);
                secondEdgeRay = point - (sourceCenter + perpendicularOffset);
            }

            {
                Vector2f sourceToPoint = nextPoint - sourceCenter;

                Vector2f perpendicularOffset(-sourceToPoint.y, sourceToPoint.x);

                perpendicularOffset = vectorNormalize(perpendicularOffset);
                perpendicularOffset *= sourceRadius;

                firstNextEdgeRay = nextPoint - (sourceCenter - perpendicularOffset);
                secondNextEdgeRay = nextPoint - (sourceCenter + perpendicularOffset);
            }

            Vector2f pointToNextPoint = nextPoint - point;

            Vector2f normal = vectorNormalize(Vector2f(-pointToNextPoint.y, pointToNextPoint.x));

            // Front facing, mark it
            facingFrontBothEdges ~= (vectorDot(firstEdgeRay, normal) > 0.0f && vectorDot(secondEdgeRay, normal) > 0.0f)
                                    || vectorDot(firstNextEdgeRay, normal) > 0.0f && vectorDot(secondNextEdgeRay, normal) > 0.0f;
            facingFrontOneEdge ~= (vectorDot(firstEdgeRay, normal) > 0.0f || vectorDot(secondEdgeRay, normal) > 0.0f)
                                    || vectorDot(firstNextEdgeRay, normal) > 0.0f || vectorDot(secondNextEdgeRay, normal) > 0.0f;
        }

        // Go through front/back facing list. Where the facing direction switches, there is a boundary
        for (int i = 1; i < numPoints; i++)
        {
            if (facingFrontBothEdges[i] != facingFrontBothEdges[i - 1])
            {
                innerBoundaryIndices ~= i;
                bothEdgesBoundaryWindings ~= facingFrontBothEdges[i];
            }
        }

        // Check looping indices separately
        if (facingFrontBothEdges[0] != facingFrontBothEdges[numPoints - 1])
        {
            innerBoundaryIndices ~= 0;
            bothEdgesBoundaryWindings ~= facingFrontBothEdges[0];
        }

        // Go through front/back facing list. Where the facing direction switches, there is a boundary
        for (int i = 1; i < numPoints; i++)
        {
            if (facingFrontOneEdge[i] != facingFrontOneEdge[i - 1])
            {
                outerBoundaryIndices ~= i;
                oneEdgeBoundaryWindings ~= facingFrontOneEdge[i];
            }
        }

        // Check looping indices separately
        if (facingFrontOneEdge[0] != facingFrontOneEdge[numPoints - 1])
        {
            outerBoundaryIndices ~= 0;
            oneEdgeBoundaryWindings ~= facingFrontOneEdge[0];
        }

        // Compute outer boundary vectors
        for (int bi = 0; bi < outerBoundaryIndices.size(); bi++)
        {
            int penumbraIndex = outerBoundaryIndices[bi];
            bool winding = oneEdgeBoundaryWindings[bi];

            Vector2f point = shape.getTransform().transformPoint(shape.getPoint(penumbraIndex));

            Vector2f sourceToPoint = point - sourceCenter;

            Vector2f perpendicularOffset(-sourceToPoint.y, sourceToPoint.x);

            perpendicularOffset = vectorNormalize(perpendicularOffset);
            perpendicularOffset *= sourceRadius;

            Vector2f firstEdgeRay = point - (sourceCenter + perpendicularOffset);
            Vector2f secondEdgeRay = point - (sourceCenter - perpendicularOffset);

            // Add boundary vector
            outerBoundaryVectors ~= winding ? firstEdgeRay : secondEdgeRay;
        }

        for (int bi = 0; bi < innerBoundaryIndices.size(); bi++)
        {
            int penumbraIndex = innerBoundaryIndices[bi];
            bool winding = bothEdgesBoundaryWindings[bi];

            Vector2f point = shape.getTransform().transformPoint(shape.getPoint(penumbraIndex));

            Vector2f sourceToPoint = point - sourceCenter;

            Vector2f perpendicularOffset = Vector2f(-sourceToPoint.y, sourceToPoint.x);

            perpendicularOffset = vectorNormalize(perpendicularOffset);
            perpendicularOffset *= sourceRadius;

            Vector2f firstEdgeRay = point - (sourceCenter + perpendicularOffset);
            Vector2f secondEdgeRay = point - (sourceCenter - perpendicularOffset);

            // Add boundary vector
            innerBoundaryVectors ~= winding ? secondEdgeRay : firstEdgeRay;
            Vector2f outerBoundaryVector = winding ? firstEdgeRay : secondEdgeRay;

            if (innerBoundaryIndices.size() == 1)
                innerBoundaryVectors~= (outerBoundaryVector);

            // Add penumbras
            bool hasPrevPenumbra = false;

            Vector2f prevPenumbraLightEdgeVector;

            float prevBrightness = 1.0f;

            int counter = 0;

            while (penumbraIndex != -1)
            {
                Vector2f nextPoint;
                int nextPointIndex;

                if (penumbraIndex < numPoints - 1)
                {
                    nextPointIndex = penumbraIndex + 1;
                    nextPoint = shape.getTransform().transformPoint(shape.getPoint(penumbraIndex + 1));
                }
                else
                {
                    nextPointIndex = 0;
                    nextPoint = shape.getTransform().transformPoint(shape.getPoint(0));
                }

                Vector2f pointToNextPoint = nextPoint - point;

                Vector2f prevPoint;
                int prevPointIndex;

                if (penumbraIndex > 0)
                {
                    prevPointIndex = penumbraIndex - 1;
                    prevPoint = shape.getTransform().transformPoint(shape.getPoint(penumbraIndex - 1));
                }
                else
                {
                    prevPointIndex = numPoints - 1;
                    prevPoint = shape.getTransform().transformPoint(shape.getPoint(numPoints - 1));
                }

                Vector2f pointToPrevPoint = prevPoint - point;

                Penumbra penumbra;

                penumbra.source = point;

                if (!winding)
                {
                    if (hasPrevPenumbra)
                        penumbra.lightEdge = prevPenumbraLightEdgeVector;
                    else
                        penumbra.lightEdge = innerBoundaryVectors[$-1];

                    penumbra.darkEdge = outerBoundaryVector;

                    penumbra.lightBrightness = prevBrightness;

                    // Next point, check for intersection
                    float intersectionAngle = acos(vectorDot(vectorNormalize(penumbra.lightEdge), vectorNormalize(pointToNextPoint)));
                    float penumbraAngle = acos(vectorDot(vectorNormalize(penumbra.lightEdge), vectorNormalize(penumbra.darkEdge)));

                    if (intersectionAngle < penumbraAngle)
                    {
                        prevBrightness = penumbra.darkBrightness = intersectionAngle / penumbraAngle;

                        assert(prevBrightness >= 0.0f && prevBrightness <= 1.0f);

                        penumbra.darkEdge = pointToNextPoint;

                        penumbraIndex = nextPointIndex;

                        if (hasPrevPenumbra)
                        {
                            swap(penumbra.darkBrightness, penumbras[$-1].darkBrightness);
                            swap(penumbra.lightBrightness, penumbras[$-1].lightBrightness);
                        }

                        hasPrevPenumbra = true;

                        prevPenumbraLightEdgeVector = penumbra.darkEdge;

                        point = shape.getTransform().transformPoint(shape.getPoint(penumbraIndex));

                        sourceToPoint = point - sourceCenter;

                        perpendicularOffset = Vector2f(-sourceToPoint.y, sourceToPoint.x);

                        perpendicularOffset = vectorNormalize(perpendicularOffset);
                        perpendicularOffset *= sourceRadius;

                        firstEdgeRay = point - (sourceCenter + perpendicularOffset);
                        secondEdgeRay = point - (sourceCenter - perpendicularOffset);

                        outerBoundaryVector = secondEdgeRay;

                        if (!outerBoundaryVectors.empty())
                        {
                            outerBoundaryVectors[0] = penumbra.darkEdge;
                            outerBoundaryIndices[0] = penumbraIndex;
                        }
                    }
                    else
                    {
                        penumbra.darkBrightness = 0.0f;

                        if (hasPrevPenumbra)
                        {
                            swap(penumbra.darkBrightness, penumbras[$-1].darkBrightness);
                            swap(penumbra.lightBrightness, penumbras[$-1].lightBrightness);
                        }

                        hasPrevPenumbra = false;

                        if (!outerBoundaryVectors.empty()) {
                            outerBoundaryVectors[0] = penumbra.darkEdge;
                            outerBoundaryIndices[0] = penumbraIndex;
                        }

                        penumbraIndex = -1;
                    }
                }
                else
                {
                    if (hasPrevPenumbra)
                        penumbra.lightEdge = prevPenumbraLightEdgeVector;
                    else
                        penumbra.lightEdge = innerBoundaryVectors[$-1];

                    penumbra.darkEdge = outerBoundaryVector;

                    penumbra.lightBrightness = prevBrightness;

                    // Next point, check for intersection
                    float intersectionAngle = acos(vectorDot(vectorNormalize(penumbra.lightEdge), vectorNormalize(pointToPrevPoint)));
                    float penumbraAngle = acos(vectorDot(vectorNormalize(penumbra.lightEdge), vectorNormalize(penumbra.darkEdge)));

                    if (intersectionAngle < penumbraAngle)
                    {
                        prevBrightness = penumbra.darkBrightness = intersectionAngle / penumbraAngle;

                        assert(prevBrightness >= 0.0f && prevBrightness <= 1.0f);

                        penumbra.darkEdge = pointToPrevPoint;

                        penumbraIndex = prevPointIndex;

                        if (hasPrevPenumbra)
                        {
                            swap(penumbra.darkBrightness, penumbras[$-1].darkBrightness);
                            swap(penumbra.lightBrightness, penumbras[$-1].lightBrightness);
                        }

                        hasPrevPenumbra = true;

                        prevPenumbraLightEdgeVector = penumbra.darkEdge;

                        point = shape.getTransform().transformPoint(shape.getPoint(penumbraIndex));

                        sourceToPoint = point - sourceCenter;

                        perpendicularOffset = Vector2f(-sourceToPoint.y, sourceToPoint.x);

                        perpendicularOffset = vectorNormalize(perpendicularOffset);
                        perpendicularOffset *= sourceRadius;

                        firstEdgeRay = point - (sourceCenter + perpendicularOffset);
                        secondEdgeRay = point - (sourceCenter - perpendicularOffset);

                        outerBoundaryVector = firstEdgeRay;

                        if (outerBoundaryVectors.length > 0)
                        {
                            outerBoundaryVectors[1] = penumbra.darkEdge;
                            outerBoundaryIndices[1] = penumbraIndex;
                        }
                    }
                    else
                    {
                        penumbra.darkBrightness = 0.0f;

                        if (hasPrevPenumbra)
                        {
                            swap(penumbra.darkBrightness, penumbras[$-1].darkBrightness);
                            swap(penumbra.lightBrightness, penumbras[$-1].lightBrightness);
                        }

                        hasPrevPenumbra = false;

                        if (!outerBoundaryVectors.empty())
                        {
                            outerBoundaryVectors[1] = penumbra.darkEdge;
                            outerBoundaryIndices[1] = penumbraIndex;
                        }

                        penumbraIndex = -1;
                    }
                }

                penumbras ~= penumbra;

                counter++;
            }
        }
    }

    static void getPenumbrasDirection(Penumbra[] penumbras,
                int[] innerBoundaryIndices,
                Vector2f[] innerBoundaryVectors,
                int[] outerBoundaryIndices,
                Vector2f[] outerBoundaryVectors,
                ref const(ConvexShape) shape,
                ref const(Vector2f) sourceDirection,
                float sourceRadius, float sourceDistance)
    {
        const int numPoints = shape.getPointCount();

        bool[] bothEdgesBoundaryWindings;

        // Calculate front and back facing sides
        bool[] facingFrontBothEdges;

        bool[] facingFrontOneEdge;

        for (int i = 0; i < numPoints; i++)
        {
            Vector2f point = shape.getTransform().transformPoint(shape.getPoint(i));

            Vector2f nextPoint;

            if (i < numPoints - 1)
                nextPoint = shape.getTransform().transformPoint(shape.getPoint(i + 1));
            else
                nextPoint = shape.getTransform().transformPoint(shape.getPoint(0));

            Vector2f firstEdgeRay;
            Vector2f secondEdgeRay;
            Vector2f firstNextEdgeRay;
            Vector2f secondNextEdgeRay;

            Vector2f perpendicularOffset = Vector2f(-sourceDirection.y, sourceDirection.x);

            perpendicularOffset = vectorNormalize(perpendicularOffset);
            perpendicularOffset *= sourceRadius;

            firstEdgeRay = point - (point - sourceDirection * sourceDistance - perpendicularOffset);
            secondEdgeRay = point - (point - sourceDirection * sourceDistance + perpendicularOffset);

            firstNextEdgeRay = nextPoint - (point - sourceDirection * sourceDistance - perpendicularOffset);
            secondNextEdgeRay = nextPoint - (point - sourceDirection * sourceDistance + perpendicularOffset);

            Vector2f pointToNextPoint = nextPoint - point;

            Vector2f normal = vectorNormalize(Vector2f(-pointToNextPoint.y, pointToNextPoint.x));

            // Front facing, mark it
            facingFrontBothEdges ~= ((vectorDot(firstEdgeRay, normal) > 0.0f && vectorDot(secondEdgeRay, normal) > 0.0f) || vectorDot(firstNextEdgeRay, normal) > 0.0f && vectorDot(secondNextEdgeRay, normal) > 0.0f);
            facingFrontOneEdge ~= ((vectorDot(firstEdgeRay, normal) > 0.0f || vectorDot(secondEdgeRay, normal) > 0.0f) || vectorDot(firstNextEdgeRay, normal) > 0.0f || vectorDot(secondNextEdgeRay, normal) > 0.0f);
        }

        // Go through front/back facing list. Where the facing direction switches, there is a boundary
        for (int i = 1; i < numPoints; i++)
        {
            if (facingFrontBothEdges[i] != facingFrontBothEdges[i - 1])
            {
                innerBoundaryIndices ~= i;
                bothEdgesBoundaryWindings ~= facingFrontBothEdges[i];
            }
        }

        // Check looping indices separately
        if (facingFrontBothEdges[0] != facingFrontBothEdges[numPoints - 1])
        {
            innerBoundaryIndices ~= 0;
            bothEdgesBoundaryWindings ~= facingFrontBothEdges[0];
        }

        // Go through front/back facing list. Where the facing direction switches, there is a boundary
        for (int i = 1; i < numPoints; i++)
            if (facingFrontOneEdge[i] != facingFrontOneEdge[i - 1])
                outerBoundaryIndices ~= i;

        // Check looping indices separately
        if (facingFrontOneEdge[0] != facingFrontOneEdge[numPoints - 1])
            outerBoundaryIndices ~= 0;

        for (int bi = 0; bi < innerBoundaryIndices.size(); bi++)
        {
            int penumbraIndex = innerBoundaryIndices[bi];
            bool winding = bothEdgesBoundaryWindings[bi];

            Vector2f point = shape.getTransform().transformPoint(shape.getPoint(penumbraIndex));

            Vector2f perpendicularOffset(-sourceDirection.y, sourceDirection.x);

            perpendicularOffset = vectorNormalize(perpendicularOffset);
            perpendicularOffset *= sourceRadius;

            Vector2f firstEdgeRay = point - (point - sourceDirection * sourceDistance + perpendicularOffset);
            Vector2f secondEdgeRay = point - (point - sourceDirection * sourceDistance - perpendicularOffset);

            // Add boundary vector
            innerBoundaryVectors ~= (winding ? secondEdgeRay : firstEdgeRay);
            Vector2f outerBoundaryVector = winding ? firstEdgeRay : secondEdgeRay;

            outerBoundaryVectors ~= outerBoundaryVector;

            // Add penumbras
            bool hasPrevPenumbra = false;

            Vector2f prevPenumbraLightEdgeVector;

            float prevBrightness = 1.0f;

            int counter = 0;

            while (penumbraIndex != -1)
            {
                Vector2f nextPoint;
                int nextPointIndex;

                if (penumbraIndex < numPoints - 1)
                {
                    nextPointIndex = penumbraIndex + 1;
                    nextPoint = shape.getTransform().transformPoint(shape.getPoint(penumbraIndex + 1));
                }
                else
                {
                    nextPointIndex = 0;
                    nextPoint = shape.getTransform().transformPoint(shape.getPoint(0));
                }

                Vector2f pointToNextPoint = nextPoint - point;

                Vector2f prevPoint;
                int prevPointIndex;

                if (penumbraIndex > 0)
                {
                    prevPointIndex = penumbraIndex - 1;
                    prevPoint = shape.getTransform().transformPoint(shape.getPoint(penumbraIndex - 1));
                }
                else
                {
                    prevPointIndex = numPoints - 1;
                    prevPoint = shape.getTransform().transformPoint(shape.getPoint(numPoints - 1));
                }

                Vector2f pointToPrevPoint = prevPoint - point;

                Penumbra penumbra;

                penumbra.source = point;

                if (!winding)
                {
                    if (hasPrevPenumbra)
                        penumbra.lightEdge = prevPenumbraLightEdgeVector;
                    else
                        penumbra.lightEdge = innerBoundaryVectors[$-1];

                    penumbra.darkEdge = outerBoundaryVector;

                    penumbra.lightBrightness = prevBrightness;

                    // Next point, check for intersection
                    float intersectionAngle = acos(vectorDot(vectorNormalize(penumbra.lightEdge), vectorNormalize(pointToNextPoint)));
                    float penumbraAngle = acos(vectorDot(vectorNormalize(penumbra.lightEdge), vectorNormalize(penumbra.darkEdge)));

                    if (intersectionAngle < penumbraAngle)
                    {
                        prevBrightness = penumbra.darkBrightness = intersectionAngle / penumbraAngle;

                        assert(prevBrightness >= 0.0f && prevBrightness <= 1.0f);

                        penumbra.darkEdge = pointToNextPoint;

                        penumbraIndex = nextPointIndex;

                        if (hasPrevPenumbra)
                        {
                            swap(penumbra.darkBrightness, penumbras[$-1].darkBrightness);
                            swap(penumbra.lightBrightness, penumbras[$-1].lightBrightness);
                        }

                        hasPrevPenumbra = true;

                        prevPenumbraLightEdgeVector = penumbra.darkEdge;

                        point = shape.getTransform().transformPoint(shape.getPoint(penumbraIndex));

                        perpendicularOffset = Vector2f(-sourceDirection.y, sourceDirection.x);

                        perpendicularOffset = vectorNormalize(perpendicularOffset);
                        perpendicularOffset *= sourceRadius;

                        firstEdgeRay = point - (point - sourceDirection * sourceDistance + perpendicularOffset);
                        secondEdgeRay = point - (point - sourceDirection * sourceDistance - perpendicularOffset);

                        outerBoundaryVector = secondEdgeRay;
                    }
                    else
                    {
                        penumbra.darkBrightness = 0.0f;

                        if (hasPrevPenumbra)
                        {
                            swap(penumbra.darkBrightness, penumbras[$-1].darkBrightness);
                            swap(penumbra.lightBrightness, penumbras[$-1].lightBrightness);
                        }

                        hasPrevPenumbra = false;

                        penumbraIndex = -1;
                    }
                }
                else
                {
                    if (hasPrevPenumbra)
                        penumbra.lightEdge = prevPenumbraLightEdgeVector;
                    else
                        penumbra.lightEdge = innerBoundaryVectors[$-1];

                    penumbra.darkEdge = outerBoundaryVector;

                    penumbra.lightBrightness = prevBrightness;

                    // Next point, check for intersection
                    float intersectionAngle = acos(vectorDot(vectorNormalize(penumbra.lightEdge), vectorNormalize(pointToPrevPoint)));
                    float penumbraAngle = acos(vectorDot(vectorNormalize(penumbra.lightEdge), vectorNormalize(penumbra.darkEdge)));

                    if (intersectionAngle < penumbraAngle)
                    {
                        prevBrightness = penumbra.darkBrightness = intersectionAngle / penumbraAngle;

                        assert(prevBrightness >= 0.0f && prevBrightness <= 1.0f);

                        penumbra.darkEdge = pointToPrevPoint;

                        penumbraIndex = prevPointIndex;

                        if (hasPrevPenumbra)
                        {
                            swap(penumbra.darkBrightness, penumbras[$-1].darkBrightness);
                            swap(penumbra.lightBrightness, penumbras[$-1].lightBrightness);
                        }

                        hasPrevPenumbra = true;

                        prevPenumbraLightEdgeVector = penumbra.darkEdge;

                        point = shape.getTransform().transformPoint(shape.getPoint(penumbraIndex));

                        perpendicularOffset = Vector2f(-sourceDirection.y, sourceDirection.x);

                        perpendicularOffset = vectorNormalize(perpendicularOffset);
                        perpendicularOffset *= sourceRadius;

                        firstEdgeRay = point - (point - sourceDirection * sourceDistance + perpendicularOffset);
                        secondEdgeRay = point - (point - sourceDirection * sourceDistance - perpendicularOffset);

                        outerBoundaryVector = firstEdgeRay;
                    }
                    else
                    {
                        penumbra.darkBrightness = 0.0f;

                        if (hasPrevPenumbra)
                        {
                            swap(penumbra.darkBrightness, penumbras[$-1].darkBrightness);
                            swap(penumbra.lightBrightness, penumbras[$-1].lightBrightness);
                        }

                        hasPrevPenumbra = false;

                        penumbraIndex = -1;
                    }
                }

                penumbras ~= (penumbra);

                counter++;
            }
        }
    }


    static void clear(ref RenderTarget rt, ref const(Color) color)
    {
        RectangleShape shape;
        shape.setSize(Vector2f(rt.getSize().x, rt.getSize().y));
        shape.setFillColor(color);
        View v = rt.getView();
        rt.setView(rt.getDefaultView());
        rt.draw(shape);
        rt.setView(v);
    }
}
