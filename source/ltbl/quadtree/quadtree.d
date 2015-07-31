module ltbl._quadtree._quadtree;

// Base class for dynamic and static Quadtree types
class Quadtree {

    protected
    {
        QuadtreeOccupant[] _outsideRoot;
        QuadtreeNode _rootNode;
    }

    public
    {
        size_t minNumNodeOccupants;
        size_t maxNumNodeOccupants;
        size_t maxLevels;

        float oversizeMultiplier;
    }

    Quadtree()
    {
        minNumNodeOccupants = 3;
        maxNumNodeOccupants = 6;
        maxLevels = 40;
        oversizeMultiplier = 1.0f;
    }

    Quadtree(in Quadtree other) {
        minNumNodeOccupants = other.minNumNodeOccupants;
        maxNumNodeOccupants = other.maxNumNodeOccupants;
        maxLevels = other.maxLevels;
        oversizeMultiplier = other.oversizeMultiplier;

        _outsideRoot = other._outsideRoot;

        if (other._rootNode !is null) {
            _rootNode.reset(new QuadtreeNode());

            recursiveCopy(_rootNode.get(), other._rootNode.get(), null);
        }
    }

    abstract void add(ref QuadtreeOccupant oc);

    /*void pruneDeadReferences() {
        for (occupant; _outsideRoot)
        {
            if ((*it) == nullptr)
                it++;
            else
                it = _outsideRoot.erase(it);
        }

        if (_rootNode !is null)
            _rootNode.pruneDeadReferences();
    }*/

    void queryRegion(QuadtreeOccupant[] result, const ref FloatRect region) {
        // Query outside root elements
        for (occupant; _outsideRoot) {
            FloatRect r = occupant.getAABB();

            if (oc != null && region.intersects(oc.getAABB()))
            {
                // Intersects, add to list
                result ~= oc;
            }
        }

        DList!(QuadtreeNode) open;

        open.insertBack(_rootNode.get());

        while (!open.empty()) {
            // Depth-first (results in less memory usage), remove objects from open list
            QuadtreeNode current = open.back();
            open.removeBack();

            if (region.intersects(current._region)) {
                for (occupant; current._occupants) {
                    if (oc != null && region.intersects(oc.getAABB()))
                    {
                        // Visible, add to list
                        result.insertBack(oc);
                    }
                }

                // Add children to open list if they intersect the region
                if (current._hasChildren)
                {
                    for (int i = 0; i < 4; i++)
                    {
                        if (current._children[i].getNumOccupantsBelow() != 0)
                        {
                            open.push_back(current._children[i].get());
                        }
                    }
                }
            }
        }
    }


    void queryPoint(QuadtreeOccupant[] result, const ref Vector2f p) {
        // Query outside root elements
        for (occupant; _outsideRoot) {
            if (oc !is null && oc.getAABB().contains(p))
                // Intersects, add to list
                result.insertBack(oc);
        }

        DList!(QuadtreeNode) open;

        open.insertBack(_rootNode.get());

        while (!open.empty()) {
            // Depth-first (results in less memory usage), remove objects from open list
            QuadtreeNode current = open.back();
            open.removeBack();

            if (current._region.contains(p)) {
                for (qccupant; current._occupants) {
                    if (oc != null && oc.getAABB().contains(p))
                        // Visible, add to list
                        result.insertBack(oc);
                }

                // Add children to open list if they intersect the region
                if (current._hasChildren)
                {
                    for (int i = 0; i < 4; i++)
                    {
                        if (current._children[i].getNumOccupantsBelow() != 0)
                        {
                            open.insertBack(current._children[i].get());
                        }
                    }
                }
            }
        }
    }

    void queryShape(QuadtreeOccupant[] result, const ref ConvexShape shape) {
        // Query outside root elements
        for (occupant; _outsideRoot) {
            if (oc != null && shapeIntersection(shapeFromRect(oc.getAABB()), shape))
                // Intersects, add to list
                result.insertBack(oc);
        }

        DList!(QuadtreeNode) open;

        open.insertBack(_rootNode.get());

        while (!open.empty()) {
            // Depth-first (results in less memory usage), remove objects from open list
            QuadtreeNode current = open.back();
            open.removeBack();

            if (shapeIntersection(shapeFromRect(current._region), shape)) {
                for (occupant; current._occupants) {
                    ConvexShape r = shapeFromRect(oc.getAABB());

                    if (oc != null && shapeIntersection(shapeFromRect(oc.getAABB()), shape))
                        // Visible, add to list
                        result.insertBack(oc);
                }

                // Add children to open list if they intersect the region
                if (current._hasChildren)
                {
                    for (int i = 0; i < 4; i++)
                    {
                        if (current._children[i].getNumOccupantsBelow() != 0)
                        {
                            open.insertBack(current._children[i].get());
                        }
                    }
                }
            }
        }
    }


protected:
    // Called whenever something is removed, an action can be defined by derived classes
    // Defaults to doing nothing
    void onRemoval() {}

    void setQuadtree(ref QuadtreeOccupant oc) {
        oc._quadtree = this;
    }

    void recursiveCopy(ref QuadtreeNode thisNode, ref QuadtreeNode otherNode, ref QuadtreeNode thisParent) {
        thisNode._hasChildren = otherNode._hasChildren;
        thisNode._level = otherNode._level;
        thisNode._numOccupantsBelow = otherNode._numOccupantsBelow;
        thisNode._occupants = otherNode._occupants;
        thisNode._region = otherNode._region;

        thisNode._parent = thisParent;

        thisNode._quadtree = this;

        if (thisNode._hasChildren)
        {
            for (int i = 0; i < 4; i++) {
                thisNode._children[i].reset(new QuadtreeNode());

                recursiveCopy(thisNode._children[i].get(), otherNode._children[i].get(), thisNode);
            }
        }
    }
}
