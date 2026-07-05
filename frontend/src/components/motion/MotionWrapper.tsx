'use client'

import { motion, HTMLMotionProps } from 'framer-motion'
import { ReactNode } from 'react'

export const heavyPhysics = {
  type: 'spring',
  mass: 1.5,
  stiffness: 50,
  damping: 20
}

interface MotionWrapperProps extends HTMLMotionProps<"div"> {
  children: ReactNode
}

/**
 * Base MotionWrapper applying the 2026-standard cinematic motion constraints.
 * Uses heavy physics (high mass, dampening) instead of default bouncy springs.
 */
export default function MotionWrapper({ children, ...props }: MotionWrapperProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={heavyPhysics}
      {...props}
    >
      {children}
    </motion.div>
  )
}
