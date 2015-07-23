package ltbl.quadtree.quadtree;

// Base class for dynamic and static Quadtree types
class Quadtree {

protected:
    std::unordered_set<QuadtreeOccupant*> mOutsideRoot;

    std::unique_ptr<QuadtreeNode> mRootNode;

    // Called whenever something is removed, an action can be defined by derived classes
    // Defaults to doing nothing
    void onRemoval() {}

    void setQuadtree(ref QuadtreeOccupant oc) {
        oc.quadtree = this;
    }

    void recursiveCopy(ref QuadtreeNode thisNode, ref QuadtreeNode otherNode, ref QuadtreeNode thisParent) {
        thisNode.hasChildren = otherNode.hasChildren;
        thisNode.level = otherNode.level;
        thisNode.numOccupantsBelow = otherNode.numOccupantsBelow;
        thisNode.occupants = otherNode.occupants;
        thisNode.region = otherNode.region;

        thisNode.parent = thisParent;

        thisNode.quadtree = this;

        if (thisNode.hasChildren)
        for (int i = 0; i < 4; i++) {
            thisNode.children[i].reset(new QuadtreeNode());

            recursiveCopy(thisNode.children[i].get(), otherNode.children[i].get(), thisNode);
        }
    }

public:
    size_t m_minNumNodeOccupants;
    size_t m_maxNumNodeOccupants;
    size_t m_maxLevels;

    float m_oversizeMultiplier;

    Quadtree()
    : m_minNumNodeOccupants(3),
    m_maxNumNodeOccupants(6),
    m_maxLevels(40),
    m_oversizeMultiplier(1.0f)
    {}

    Quadtree(const Quadtree &other) {
        *this = other;
    }

    void operator=(const Quadtree &other) {
        m_minNumNodeOccupants = other.m_minNumNodeOccupants;
        m_maxNumNodeOccupants = other.m_maxNumNodeOccupants;
        m_maxLevels = other.m_maxLevels;
        m_oversizeMultiplier = other.m_oversizeMultiplier;

        mOutsideRoot = other.mOutsideRoot;

        if (other.mRootNode != nullptr) {
            mRootNode.reset(new QuadtreeNode());

            recursiveCopy(mRootNode.get(), other.mRootNode.get(), nullptr);
        }
    }

    abstract void add(QuadtreeOccupant* oc);

    void pruneDeadReferences() {
        for (std::unordered_set<QuadtreeOccupant*>::iterator it = mOutsideRoot.begin(); it != mOutsideRoot.end();)
        if ((*it) == nullptr)
            it++;
        else
            it = mOutsideRoot.erase(it);

        if (mRootNode != nullptr)
            mRootNode.pruneDeadReferences();
    }

    void queryRegion(std::vector<QuadtreeOccupant*> &result, const sf::FloatRect &region) {
        // Query outside root elements
        for (std::unordered_set<QuadtreeOccupant*>::iterator it = mOutsideRoot.begin(); it != mOutsideRoot.end(); it++) {
            QuadtreeOccupant* oc = *it;
            sf::FloatRect r = oc.getAABB();

            if (oc != nullptr && region.intersects(oc.getAABB()))
                // Intersects, add to list
                result.push_back(oc);
        }

        std::list<QuadtreeNode*> open;

        open.push_back(mRootNode.get());

        while (!open.empty()) {
            // Depth-first (results in less memory usage), remove objects from open list
            QuadtreeNode* pCurrent = open.back();
            open.pop_back();

            if (region.intersects(pCurrent.region)) {
                for (std::unordered_set<QuadtreeOccupant*>::iterator it = pCurrent.occupants.begin(); it != pCurrent.occupants.end(); it++) {
                    QuadtreeOccupant* oc = *it;

                    if (oc != nullptr && region.intersects(oc.getAABB()))
                        // Visible, add to list
                        result.push_back(oc);
                }

                // Add children to open list if they intersect the region
                if (pCurrent.hasChildren)
                for (int i = 0; i < 4; i++)
                if (pCurrent.children[i].getNumOccupantsBelow() != 0)
                    open.push_back(pCurrent.children[i].get());
            }
        }
    }


    void queryPoint(std::vector<QuadtreeOccupant*> &result, const sf::Vector2f &p) {
        // Query outside root elements
        for (std::unordered_set<QuadtreeOccupant*>::iterator it = mOutsideRoot.begin(); it != mOutsideRoot.end(); it++) {
            QuadtreeOccupant* oc = *it;

            if (oc != nullptr && oc.getAABB().contains(p))
                // Intersects, add to list
                result.push_back(oc);
        }

        std::list<QuadtreeNode*> open;

        open.push_back(mRootNode.get());

        while (!open.empty()) {
            // Depth-first (results in less memory usage), remove objects from open list
            QuadtreeNode* pCurrent = open.back();
            open.pop_back();

            if (pCurrent.region.contains(p)) {
                for (std::unordered_set<QuadtreeOccupant*>::iterator it = pCurrent.occupants.begin(); it != pCurrent.occupants.end(); it++) {
                    QuadtreeOccupant* oc = *it;

                    if (oc != nullptr && oc.getAABB().contains(p))
                        // Visible, add to list
                        result.push_back(oc);
                }

                // Add children to open list if they intersect the region
                if (pCurrent.hasChildren)
                for (int i = 0; i < 4; i++)
                if (pCurrent.children[i].getNumOccupantsBelow() != 0)
                    open.push_back(pCurrent.children[i].get());
            }
        }
    }

    void queryShape(std::vector<QuadtreeOccupant*> &result, const sf::ConvexShape &shape) {
        // Query outside root elements
        for (std::unordered_set<QuadtreeOccupant*>::iterator it = mOutsideRoot.begin(); it != mOutsideRoot.end(); it++) {
            QuadtreeOccupant* oc = *it;

            if (oc != nullptr && shapeIntersection(shapeFromRect(oc.getAABB()), shape))
                // Intersects, add to list
                result.push_back(oc);
        }

        std::list<QuadtreeNode*> open;

        open.push_back(mRootNode.get());

        while (!open.empty()) {
            // Depth-first (results in less memory usage), remove objects from open list
            QuadtreeNode* pCurrent = open.back();
            open.pop_back();

            if (shapeIntersection(shapeFromRect(pCurrent.region), shape)) {
                for (std::unordered_set<QuadtreeOccupant*>::iterator it = pCurrent.occupants.begin(); it != pCurrent.occupants.end(); it++) {
                    QuadtreeOccupant* oc = *it;
                    sf::ConvexShape r = shapeFromRect(oc.getAABB());

                    if (oc != nullptr && shapeIntersection(shapeFromRect(oc.getAABB()), shape))
                        // Visible, add to list
                        result.push_back(oc);
                }

                // Add children to open list if they intersect the region
                if (pCurrent.hasChildren)
                for (int i = 0; i < 4; i++)
                if (pCurrent.children[i].getNumOccupantsBelow() != 0)
                    open.push_back(pCurrent.children[i].get());
            }
        }
    }


    friend class QuadtreeNode;
    friend class SceneObject;
}
