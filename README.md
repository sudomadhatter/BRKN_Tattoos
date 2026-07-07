# BRKN Tattoos

BRKN Tattoos is a premium custom tattoo studio booking platform and portfolio showcase for Mr. BRKN. The site features an immersive design with a bespoke 3D scrolling experience.

## Tech Stack

The platform is built using a modern, decoupled architecture:

### Frontend
- **Framework:** Next.js (16) & React (19)
- **Styling:** Tailwind CSS (3.4)
- **Animations:** Framer Motion (12)
- **Smooth Scrolling:** Lenis
- **State Management:** Zustand
- **Deployment & Integrations:** Vercel (Auto-deployments from GitHub) & Resend (Emails)

### Backend
- **Framework:** FastAPI & Uvicorn
- **AI Integration:** Google ADK (Agent Development Kit) & Google GenAI
- **Realtime:** SSE Starlette (Server-Sent Events)

---

## The "Fall Into The Ink" Experience

One of the most complex and engaging parts of the site is the "Fall Into The Ink" section (`FallingGallery.tsx`). This section creates a 3D tunnel illusion where the user feels like they are falling endlessly past tattoo artwork as they scroll down the page.

### How We Built It

We achieved this effect using **Framer Motion's scroll-linked animations (`useScroll` and `useTransform`) combined with Lenis smooth scrolling**.

Here is the technical breakdown of the implementation:

1. **The Scroll Track & Sticky Container**
   The entire section is wrapped in a container that is `400vh` tall. This gives the user a massive scroll track to scrub through. Inside that container, a `sticky h-screen` `div` pins the actual visual content to the viewport.

2. **Scroll Progress Tracking**
   We use `framer-motion`'s `useScroll` hook on the `400vh` container to track the user's scroll position, mapping it to a `scrollYProgress` value between `0` (start) and `1` (end).

3. **Three-Phase Animation Sequence**
   We map the `scrollYProgress` using `useTransform` to control opacity and scale across three distinct phases:
   
   - **Phase 1: The Intro (0.0 to 0.25)**
     The massive "Fall Into The Ink" text starts fully visible. As the user begins scrolling, it slowly fades out and scales up slightly (1x to 1.5x) to pull the user in and clear the screen for the images.
   
   - **Phase 2: The Falling Images (0.12 to 0.76)**
     This is the core effect. We have an array of four image cards. Each card is mapped to a specific overlapping scroll range (e.g., `[0.12, 0.34]`, `[0.26, 0.48]`). 
     For each image, `useTransform` maps its specific scroll range to:
     - **Scale:** Grows massively from `0.5` up to `4.0`, giving the illusion of the image starting far away and rushing past the camera.
     - **Opacity:** Fades in from `0` to `1` during the first half of its range, then fades out back to `0` during the second half.
     - **Offset:** Each image has a hardcoded CSS translation (e.g., `-translate-x-20 translate-y-10`) so they appear scattered in 3D space rather than perfectly centered.
   
   - **Phase 3: The Artist Reveal (0.72 to 1.0)**
     As the final falling image clears the screen, the Mr. BRKN artist profile slide fades in and scales up to `1.0`. It holds fully opaque for the remainder of the scroll track until the next section of the website scrolls up over it.

4. **Performance Optimizations**
   To ensure this runs smoothly at 60fps on mobile devices:
   - We use `willChange: "transform, opacity"` on the animated divs.
   - We heavily rely on hardware-accelerated CSS properties (`scale` and `opacity`) rather than animating margins or top/left positions.
   - The images are rendered as background images (`bg-cover`) inside divs that use `pointer-events-none` to prevent costly layout recalculations during the scroll.
