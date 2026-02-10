import matplotlib.pyplot as plt
import matplotlib.animation as animation
import numpy as np
import random
import math
from pathfinding import PathFinder 

# --- CONFIGURATION ---
GRID_CELLS_PER_SECOND = 15
SMOOTHNESS = 5              
TOTAL_FPS = GRID_CELLS_PER_SECOND * SMOOTHNESS
INTERVAL_MS = int(1000 / TOTAL_FPS) 

def generate_shopping_mall(width=50, height=50):
    grid = np.zeros((width, height), dtype=int)
    
    # Outer Walls
    grid[0, :] = 1; grid[-1, :] = 1; grid[:, 0] = 1; grid[:, -1] = 1

    # Add Stores
    num_stores = 30 
    
    attempts = 0
    while attempts < 2000 and num_stores > 0:
        attempts += 1
        h = random.randint(3, 10)
        w = random.randint(3, 10)
        r = random.randint(2, width - h - 2)
        c = random.randint(2, height - w - 2)
        
        # We keep the physical padding integer (2) since grid cells must be whole numbers,
        # but the algorithm will treat it as a tight squeeze.
        padding = 2 
        
        r_start, r_end = max(0, r - padding), min(width, r + h + padding)
        c_start, c_end = max(0, c - padding), min(height, c + w + padding)
        
        region = grid[r_start:r_end, c_start:c_end]
        
        if np.sum(region) == 0:
            grid[r:r+h, c:c+w] = 1
            num_stores -= 1
            
    # Add Random Kiosks (Small obstacles)
    for _ in range(8):
        r, c = random.randint(5, 45), random.randint(5, 45)
        if grid[r][c] == 0:
            grid[r:r+1, c:c+1] = 1 

    return grid.tolist()

def get_random_open_point(grid):
    rows, cols = len(grid), len(grid[0])
    while True:
        r, c = random.randint(0, rows - 1), random.randint(0, cols - 1)
        if grid[r][c] == 0: return (0, r, c)

def interpolate_for_animation(clean_path):
    if not clean_path: return []
    anim_path = []
    for i in range(len(clean_path) - 1):
        start, end = clean_path[i], clean_path[i+1]
        dist = math.sqrt((end[1]-start[1])**2 + (end[2]-start[2])**2)
        frames = max(1, int(dist * SMOOTHNESS))
        for step in range(frames):
            frac = step / frames
            r = start[1] + (end[1] - start[1]) * frac
            c = start[2] + (end[2] - start[2]) * frac
            anim_path.append((start[0], r, c))
    anim_path.append(clean_path[-1])
    return anim_path

def main():
    print("\n--- Starting Simulation ---")
    
    grid = generate_shopping_mall(50, 50)
    finder = PathFinder([grid], {})

    start = get_random_open_point(grid)
    goal = get_random_open_point(grid)
    while start == goal: goal = get_random_open_point(grid)

    print("Calculating path...")
    clean_path = finder.find_path(start, goal)
    
    if not clean_path:
        print("Path blocked. Retrying...")
        main(); return

    final_anim_path = interpolate_for_animation(clean_path)

    print(f"Path Found!")
    
    # Updated Line: This sets the Window Title
    fig, ax = plt.subplots(figsize=(8, 8), num="Map Simulation (1.2 padding, 1.2 safety block)")
    
    ax.imshow(grid, cmap='Greys', origin='upper')
    ax.set_title("Shopping Mall (Standard Safety)")
    
    user_dot, = ax.plot([], [], 'bo', markersize=8) 
    trail_line, = ax.plot([], [], 'b-', linewidth=2, alpha=0.5)
    
    wy = [p[1] for p in clean_path]
    wx = [p[2] for p in clean_path]
    ax.plot(wx, wy, 'g.', markersize=5, alpha=0.3, label='Waypoints')
    ax.plot(start[2], start[1], 'go', markersize=10, label='Start')
    ax.plot(goal[2], goal[1], 'rX', markersize=12, label='Goal')
    ax.legend()

    def update(frame):
        if frame >= len(final_anim_path): return user_dot, trail_line
        node = final_anim_path[frame]
        user_dot.set_data([node[2]], [node[1]]) 
        if frame % 5 == 0:
            past = final_anim_path[:frame+1]
            trail_line.set_data([p[2] for p in past], [p[1] for p in past])
        return user_dot, trail_line

    ani = animation.FuncAnimation(fig, update, frames=len(final_anim_path), interval=INTERVAL_MS, blit=True, repeat=False)
    plt.show(block=True) 

if __name__ == '__main__':
    main()
    