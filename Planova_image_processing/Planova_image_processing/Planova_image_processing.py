import cv2
import numpy as np
import os


#load & preprocess floor plan
def preprocess_floorplan(image_path):
    original = cv2.imread(image_path)
    if original is None:
        print("Error: Image not found!")
        return None, None, None

    gray = cv2.cvtColor(original, cv2.COLOR_BGR2GRAY)

    #binary threshold to detect walls
    #walls = white, walkable = black
    _, walls = cv2.threshold(
        gray, 200, 255, cv2.THRESH_BINARY_INV
    )

    return original, gray, walls



#create walkable map
def create_walkable_map(walls):
    #invert so walkable space becomes white
    walkable = cv2.bitwise_not(walls)
    return walkable



#overlay grid on image

def overlay_grid(image, cell_size=20):
    grid_img = image.copy()
    h, w = grid_img.shape[:2]

    for x in range(0, w, cell_size):
        cv2.line(grid_img, (x, 0), (x, h), (0, 255, 0), 1)

    for y in range(0, h, cell_size):
        cv2.line(grid_img, (0, y), (w, y), (0, 255, 0), 1)

    return grid_img



#convert walkable map to grid
#0 = walkable, 1 = wall
def walkable_to_grid(walkable, cell_size=20):
    h, w = walkable.shape
    rows = h // cell_size
    cols = w // cell_size

    grid = np.zeros((rows, cols), dtype=np.uint8)

    for y in range(rows):
        for x in range(cols):
            cell = walkable[
                y * cell_size:(y + 1) * cell_size,
                x * cell_size:(x + 1) * cell_size
            ]

            #if dark pixels exist ? wall
            if np.mean(cell) < 200:
                grid[y, x] = 1  # wall
            else:
                grid[y, x] = 0  # walkable

    return grid



#visualize grid (RED=wall, GREEN=walkable)
def visualize_grid(grid, cell_size=20):
    rows, cols = grid.shape
    vis = np.zeros((rows * cell_size, cols * cell_size, 3), dtype=np.uint8)

    for y in range(rows):
        for x in range(cols):
            if grid[y, x] == 1:
                color = (0, 0, 255)   #red = wall
            else:
                color = (0, 255, 0)   #green = walkable

            cv2.rectangle(
                vis,
                (x * cell_size, y * cell_size),
                ((x + 1) * cell_size, (y + 1) * cell_size),
                color,
                -1
            )

    #draw grid lines
    for x in range(0, vis.shape[1], cell_size):
        cv2.line(vis, (x, 0), (x, vis.shape[0]), (0, 0, 0), 1)

    for y in range(0, vis.shape[0], cell_size):
        cv2.line(vis, (0, y), (vis.shape[1], y), (0, 0, 0), 1)

    return vis


def main():
    image_path = "floor-plan.jpeg"

    if not os.path.exists(image_path):
        print("Floor plan image not found!")
        return

    original, gray, walls = preprocess_floorplan(image_path)
    walkable = create_walkable_map(walls)

    #convert walkable to color for grid overlay
    walkable_color = cv2.cvtColor(walkable, cv2.COLOR_GRAY2BGR)
    grid_overlay = overlay_grid(walkable_color, cell_size=20)

    grid = walkable_to_grid(walkable, cell_size=20)
    grid_visual = visualize_grid(grid, cell_size=20)

    print("Grid shape:", grid.shape)
    print("0 = walkable, 1 = wall")

    cv2.imshow("Original Floor Plan", original)
    cv2.imshow("Detected Walls", walls)
    cv2.imshow("Walkable Area", walkable)
    cv2.imshow("Walkable Grid Overlay", grid_overlay)
    cv2.imshow("Grid Visualization (Green=Walkable, Red=Wall)", grid_visual)

    cv2.waitKey(0)
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
