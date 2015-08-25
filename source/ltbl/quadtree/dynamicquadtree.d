module ltbl.quadtree.dynamicquadtree;

import ltbl.quadtree.quadtree;
import ltbl.quadtree.quadtreeoccupant;

import dsfml.graphics;

class DynamicQuadtree : Quadtree {

    public
    {
        long minOutsideRoot;
        long maxOutsideRoot;
    }

    this()
    {
        minOutsideRoot = 1;
        maxOutsideRoot = 8;
    }

    this(ref const(FloatRect) rootRegion)
    {
        this();
        create(rootRegion);
    }

    void create(ref const(FloatRect) rootRegion) {
        _rootNode = new QuadtreeNode(rootRegion, 0, null, this);
    }

    // Inherited from Quadtree
    override void add(QuadtreeOccupant oc) {
        assert(created());

        // If the occupant fits in the root node
        if (rectContains(_rootNode.getRegion(), oc.getAABB()))
            _rootNode.add(oc);
        else
            _outsideRoot.insert(oc);

        setQuadtree(oc);
    }

    void clear()
    {
        _rootNode.reset();
    }

    @property bool created() const
    {
        return _rootNode != null;
    }

    @property const(FloatRect) rootRegion() const
    {
        return _rootNode.region;
    }

    // Resizes Quadtree
    void trim()
    {
        if(_rootNode.get() == null)
            return;

        // Check if should grow
        if(_outsideRoot.size() > maxOutsideRoot)
            expand();
        else if(_outsideRoot.size() < minOutsideRoot && _rootNode.hasChildren)
            contract();
    }

private:

    void expand() {
        // Find direction with most occupants
        Vector2f averageDir = Vector2f(0.0, 0.0);

        foreach(occupant; _outsideRoot)
            averageDir += vectorNormalize(rectCenter(occupant.getAABB()) - rectCenter(_rootNode.getRegion()));

        Vector2f centerOffsetDist = Vector2f(rectHalfDims(_rootNode.getRegion()) / oversizeMultiplier);

        Vector2f centerOffset = Vector2f((averageDir.x > 0.0 ? 1.0 : -1.0) * centerOffsetDist.x,
                                (averageDir.y > 0.0 ? 1.0 : -1.0) * centerOffsetDist.y);

        // Child node position of current root node
        int rX = centerOffset.x > 0.0 ? 0 : 1;
        int rY = centerOffset.y > 0.0 ? 0 : 1;

        FloatRect newRootAABB = rectFromBounds(Vector2f(0.0, 0.0), centerOffsetDist * 4.0);

        newRootAABB = rectRecenter(newRootAABB, centerOffset + rectCenter(_rootNode.getRegion()));

        QuadtreeNode newRoot = new QuadtreeNode(newRootAABB,  _rootNode.level + 1, null, this);

        // ----------------------- Manual Children Creation for New Root -------------------------

        Vector2f halfRegionDims = rectHalfDims(newRoot.region);
        Vector2f regionLowerBound = rectLowerBound(newRoot.region);
        Vector2f regionCenter = rectCenter(newRoot.region);

        // Create the children nodes
        for(int x = 0; x < 2; x++) {
            for(int y = 0; y < 2; y++) {
                if(x == rX && y == rY) {
                    newRoot.children[x + y * 2].reset(_rootNode.release());
                } else {
                    Vector2f offset = Vector2f(x * halfRegionDims.x, y * halfRegionDims.y);

                    FloatRect childAABB = rectFromBounds(regionLowerBound + offset, regionCenter + offset);

                    // Scale up AABB by the oversize multiplier
                    Vector2f center = rectCenter(childAABB);

                    childAABB.width *= oversizeMultiplier;
                    childAABB.height *= oversizeMultiplier;

                    childAABB = rectRecenter(childAABB, center);

                    newRoot.children[x + y * 2].reset(new QuadtreeNode(childAABB, _rootNode.level, newRoot, this));
                }
            }
        }

        newRoot.hasChildren = true;
        newRoot.numOccupantsBelow = _rootNode.numOccupantsBelow;
        _rootNode.parent = newRoot;

        // Transfer ownership
        _rootNode.release();
        _rootNode.reset(newRoot);

        // ----------------------- Try to Add Previously Outside Root -------------------------

        // Make copy so don't try to re-add ones just added
        QuadtreeOccupant[] outsideRootCopy = _outsideRoot.dup;
        _outsideRoot.length = 0;

        foreach(occupant; outsideRootCopy)
            add(occupant);
    }

    void contract() {
        assert(_rootNode.hasChildren);

        // Find child with the most occupants and shrink to that
        int maxIndex = 0;

        for (int i = 1; i < 4; i++) {
            if (_rootNode.children[i].getNumOccupantsBelow() >
                _rootNode.children[maxIndex].getNumOccupantsBelow())
                maxIndex = i;
        }

        // Reorganize
        for (int i = 0; i < 4; i++) {
            if (i == maxIndex)
                continue;

            _rootNode.children[i].removeForDeletion(_outsideRoot);
        }

        QuadtreeNode newRoot = _rootNode._children[maxIndex];
        _rootNode._children[maxIndex] = null;

        _rootNode.destroyChildren();

        _rootNode.removeForDeletion(_outsideRoot);

        _rootNode.reset(newRoot);

        _rootNode.parent = null;
    }
}
