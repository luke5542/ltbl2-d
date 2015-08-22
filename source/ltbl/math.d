
import std.math;

import dsfml.system;
import dsfml.graphics;

Vector2f rectCenter(in ref FloatRect rect) {
    return Vector2f(rect.left + rect.width * 0.5f, rect.top + rect.height * 0.5f);
}

bool rectIntersects(in ref FloatRect rect, in ref FloatRect other) {
    if (rect.left + rect.width < other.left)
        return false;
    if (rect.top + rect.height < other.top)
        return false;
    if (rect.left > other.left + other.width)
        return false;
    if (rect.top > other.top + other.height)
        return false;

    return true;
}

bool rectContains(in ref FloatRect rect, in ref FloatRect other) {
    if (other.left < rect.left)
        return false;
    if (other.top < rect.top)
        return false;
    if (other.left + other.width > rect.left + rect.width)
        return false;
    if (other.top + other.height > rect.top + rect.height)
        return false;

    return true;
}

Vector2f rectHalfDims(in ref FloatRect rect) {
    return Vector2f(rect.width * 0.5f, rect.height * 0.5f);
}

Vector2f rectDims(in ref FloatRect rect) {
    return Vector2f(rect.width, rect.height);
}

Vector2f rectLowerBound(in ref FloatRect rect) {
    return Vector2f(rect.left, rect.top);
}

Vector2f rectUpperBound(in ref FloatRect rect) {
    return Vector2f(rect.left + rect.width, rect.top + rect.height);
}

FloatRect rectFromBounds(in ref Vector2f lowerBound, in ref Vector2f upperBound) {
    return FloatRect(lowerBound.x, lowerBound.y, upperBound.x - lowerBound.x, upperBound.y - lowerBound.y);
}

float vectorMagnitude(in ref Vector2f vector) {
    return sqrt(vector.x * vector.x + vector.y * vector.y);
}

float vectorMagnitudeSquared(in ref Vector2f vector) {
    return vector.x * vector.x + vector.y * vector.y;
}

Vector2f vectorNormalize(in ref Vector2f vector) {
    float magnitude = vectorMagnitude(vector);

    if (magnitude == 0.0f)
        return Vector2f(1.0f, 0.0f);

    float distInv = 1.0f / magnitude;

    return Vector2f(vector.x * distInv, vector.y * distInv);
}

float vectorProject(in ref Vector2f left, in ref Vector2f right) {
    assert(vectorMagnitudeSquared(right) != 0.0f);

    return vectorDot(left, right) / vectorMagnitudeSquared(right);
}

FloatRect rectRecenter(in ref FloatRect rect, in ref Vector2f center) {
    Vector2f dims = rectDims(rect);

    return FloatRect(center - rectHalfDims(rect), dims);
}

float vectorDot(in ref Vector2f left, in ref Vector2f right) {
    return left.x * right.x + left.y * right.y;
}

FloatRect rectExpand(in ref FloatRect rect, in ref Vector2f point) {
    Vector2f lowerBound = rectLowerBound(rect);
    Vector2f upperBound = rectUpperBound(rect);

    if (point.x < lowerBound.x)
        lowerBound.x = point.x;
    else if (point.x > upperBound.x)
        upperBound.x = point.x;

    if (point.y < lowerBound.y)
        lowerBound.y = point.y;
    else if (point.y > upperBound.y)
        upperBound.y = point.y;

    return rectFromBounds(lowerBound, upperBound);
}

bool shapeIntersection(in ref ConvexShape left, in ref ConvexShape right) {
    Vector2f[] transformedLeft = new Vector2f[left.getPointCount()];

    for (int i = 0; i < left.getPointCount(); i++)
        transformedLeft[i] = left.getTransform().transformPoint(left.getPoint(i));

    Vector2f[] transformedRight = new Vector2f[right.getPointCount()];

    for (int i = 0; i < right.getPointCount(); i++)
        transformedRight[i] = right.getTransform().transformPoint(right.getPoint(i));

    for (int i = 0; i < left.getPointCount(); i++) {
        Vector2f point = transformedLeft[i];
        Vector2f nextPoint;

        if (i == left.getPointCount() - 1)
            nextPoint = transformedLeft[0];
        else
            nextPoint = transformedLeft[i + 1];

        Vector2f edge = nextPoint - point;

        // Project points from other shape onto perpendicular
        Vector2f edgePerpendicular = Vector2f(edge.y, -edge.x);

        float pointProj = vectorProject(point, edgePerpendicular);

        float minRightProj = vectorProject(transformedRight[0], edgePerpendicular);

        for (int j = 1; j < right.getPointCount(); j++) {
            float proj = vectorProject(transformedRight[j], edgePerpendicular);

            minRightProj = min(minRightProj, proj);
        }

        if (minRightProj > pointProj)
            return false;
    }

    for (int i = 0; i < right.getPointCount(); i++) {
        Vector2f point = transformedRight[i];
        Vector2f nextPoint;

        if (i == right.getPointCount() - 1)
            nextPoint = transformedRight[0];
        else
            nextPoint = transformedRight[i + 1];

        Vector2f edge = nextPoint - point;

        // Project points from other shape onto perpendicular
        Vector2f edgePerpendicular = Vector2f(edge.y, -edge.x);

        float pointProj = vectorProject(point, edgePerpendicular);

        float minRightProj = vectorProject(transformedLeft[0], edgePerpendicular);

        for (int j = 1; j < left.getPointCount(); j++) {
            float proj = vectorProject(transformedLeft[j], edgePerpendicular);

            minRightProj = min(minRightProj, proj);
        }

        if (minRightProj > pointProj)
            return false;
    }

    return true;
}

ConvexShape shapeFromRect(in ref FloatRect rect) {
    ConvexShape shape = new ConvexShape(4);

    Vector2f halfDims = rectHalfDims(rect);

    shape.setPoint(0, Vector2f(-halfDims.x, -halfDims.y));
    shape.setPoint(1, Vector2f(halfDims.x, -halfDims.y));
    shape.setPoint(2, Vector2f(halfDims.x, halfDims.y));
    shape.setPoint(3, Vector2f(-halfDims.x, halfDims.y));

    shape.setPosition(rectCenter(rect));

    return shape;
}

ConvexShape shapeFixWinding(in ref ConvexShape shape) {
    Vector2f center = Vector2f(0.0f, 0.0f);
    DList!(Vector2f) points;

    for (int i = 0; i < shape.getPointCount(); i++) {
        points.insertBack(shape.getPoint(i));
        center += shape.getPoint(i);
    }

    center /= cast(float) shape.getPointCount();

    // Fix winding
    Vector2f lastPoint = points.front();
    points.removeFront();

    Vector2f[] fixedPoints;
    fixedPoints ~= lastPoint;

    while (fixedPoints.length < shape.getPointCount()) {
        Vector2f centerToLastPoint = lastPoint - center;
        Vector2f lastPointDirection = vectorNormalize(Vector2f(-centerToLastPoint.y, centerToLastPoint.x));

        float maxD = float.min;

        Vector2f nextPoint;

        // Get next point
        foreach(point; points) {
            Vector2f toPointNormalized = vectorNormalize(point - lastPoint);

            float d = vectorDot(toPointNormalized, lastPointDirection);

            if (d > maxD) {
                maxD = d;
                nextPoint = point;
            }
        }

        fixedPoints ~= nextPoint;

        points.remove(nextPoint);
    }

    ConvexShape fixedShape = new ConvexShape(shape.getPointCount());

    for (int i = 0; i < shape.getPointCount(); i++)
        fixedShape.setPoint(i, fixedPoints[i]);

    return fixedShape;
}

bool rayIntersect(in ref Vector2f as, in ref Vector2f ad, in ref Vector2f bs,
                    in ref Vector2f bd, out Vector2f intersection) {
    float dx = bs.x - as.x;
    float dy = bs.y - as.y;
    float det = bd.x * ad.y - bd.y * ad.x;

    if (det == 0.0f)
        return false;

    float u = (dy * bd.x - dx * bd.y) / det;

    if (u < 0.0f)
        return false;

    float v = (dy * ad.x - dx * ad.y) / det;

    if (v < 0.0f)
        return false;

    intersection = as + ad * u;

    return true;
}
