module ltbl.quadtree.dynamicquadtree;

class DynamicQuadtree : public Quadtree {

public:
    long minOutsideRoot;
    long maxOutsideRoot;

    DynamicQuadtree()
    {
        minOutsideRoot = 1;
        maxOutsideRoot = 8;
    }

    DynamicQuadtree(const ref FloatRect rootRegion)
    {
        this();
        create(rootRegion);
    }

    void operator=(const DynamicQuadtree &other) {
        Quadtree::operator=(other);

        minOutsideRoot = other.minOutsideRoot;
        maxOutsideRoot = other.maxOutsideRoot;
    }

    void create(const ref FloatRect rootRegion) {
        rootNode = new QuadtreeNode(rootRegion, 0, null, this);
    }

    // Inherited from Quadtree
    void add(ref QuadtreeOccupant oc) {
        assert(created());

        // If the occupant fits in the root node
        if (rectContains(rootNode.getRegion(), oc.getAABB()))
            rootNode.add(oc);
        else
            outsideRoot.insert(oc);

        setQuadtree(oc);
    }

    void clear() {
        rootNode.reset();
    }

    // Resizes Quadtree
    void trim();

    @property bool created() {
        return rootNode != null;
    }

    const tRect getRootRegion() {
        return rootNode.getRegion();
    }

    void trim() {
        if(rootNode.get() == null)
            return;

        // Check if should grow
        if(outsideRoot.size() > maxOutsideRoot)
            expand();
        else if(outsideRoot.size() < minOutsideRoot && rootNode.hasChildren)
            contract();
    }

private:

    void expand() {
        // Find direction with most occupants
        Vector2f averageDir(0.0f, 0.0f);

        for (std::unordered_set<QuadtreeOccupant*>::iterator it = outsideRoot.begin(); it != outsideRoot.end(); it++)
            averageDir += vectorNormalize(rectCenter((*it).getAABB()) - rectCenter(rootNode.getRegion()));

        Vector2f centerOffsetDist(rectHalfDims(rootNode.getRegion()) / oversizeMultiplier);

        Vector2f centerOffset((averageDir.x > 0.0f ? 1.0f : -1.0f) * centerOffsetDist.x, //;
                                (averageDir.y > 0.0f ? 1.0f : -1.0f) * centerOffsetDist.y);

        // Child node position of current root node
        int rX = centerOffset.x > 0.0f ? 0 : 1;
        int rY = centerOffset.y > 0.0f ? 0 : 1;

        FloatRect newRootAABB = rectFromBounds(Vector2f(0.0f, 0.0f), centerOffsetDist * 4.0f);

        newRootAABB = rectRecenter(newRootAABB, centerOffset + rectCenter(rootNode.getRegion()));

        QuadtreeNode newRoot = new QuadtreeNode(newRootAABB,  rootNode.level + 1, null, this);

        // ----------------------- Manual Children Creation for New Root -------------------------

        Vector2f halfRegionDims = rectHalfDims(newRoot.region);
        Vector2f regionLowerBound = rectLowerBound(newRoot.region);
        Vector2f regionCenter = rectCenter(newRoot.region);

        // Create the children nodes
        for(int x = 0; x < 2; x++) {
            for(int y = 0; y < 2; y++) {
                if(x == rX && y == rY) {
                    newRoot.children[x + y * 2].reset(rootNode.release());
                } else {
                    Vector2f offset(x * halfRegionDims.x, y * halfRegionDims.y);

                    FloatRect childAABB = rectFromBounds(regionLowerBound + offset, regionCenter + offset);

                    // Scale up AABB by the oversize multiplier
                    Vector2f center = rectCenter(childAABB);

                    childAABB.width *= oversizeMultiplier;
                    childAABB.height *= oversizeMultiplier;

                    childAABB = rectRecenter(childAABB, center);

                    newRoot.children[x + y * 2].reset(new QuadtreeNode(childAABB, rootNode.level, newRoot, this));
                }
            }
        }

        newRoot.hasChildren = true;
        newRoot.numOccupantsBelow = rootNode.numOccupantsBelow;
        rootNode.parent = newRoot;

        // Transfer ownership
        rootNode.release();
        rootNode.reset(newRoot);

        // ----------------------- Try to Add Previously Outside Root -------------------------

        // Make copy so don't try to re-add ones just added
        std::unordered_set<QuadtreeOccupant*> outsideRootCopy(outsideRoot);
        outsideRoot.clear();

        for (std::unordered_set<QuadtreeOccupant*>::iterator it = outsideRootCopy.begin(); it != outsideRootCopy.end(); it++)
            add(*it);
    }

    void contract() {
        assert(rootNode.hasChildren);

        // Find child with the most occupants and shrink to that
        int maxIndex = 0;

        for (int i = 1; i < 4; i++)
        if (rootNode.children[i].getNumOccupantsBelow() >
            rootNode.children[maxIndex].getNumOccupantsBelow())
            maxIndex = i;

        // Reorganize
        for (int i = 0; i < 4; i++) {
            if (i == maxIndex)
                continue;

            rootNode.children[i].removeForDeletion(outsideRoot);
        }

        QuadtreeNode* newRoot = rootNode.children[maxIndex].release();

        rootNode.destroyChildren();

        rootNode.removeForDeletion(outsideRoot);

        rootNode.reset(newRoot);

        rootNode.parent = null;
    }
}
