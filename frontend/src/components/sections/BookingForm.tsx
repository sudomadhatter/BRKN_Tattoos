'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { useState } from 'react'
import { heavyPhysics } from '../motion/MotionWrapper'

export default function BookingForm() {
  const [isVerified, setIsVerified] = useState(false)

  const handleVerification = (e: React.FormEvent) => {
    e.preventDefault()
    setIsVerified(true)
  }

  // Animation variants for the staggered form fields
  const container = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1,
        delayChildren: 0.3
      }
    }
  }

  const item = {
    hidden: { opacity: 0, y: 20 },
    show: { opacity: 1, y: 0, transition: heavyPhysics }
  }

  return (
    <section className="py-24 px-6 sm:px-12 w-full max-w-4xl mx-auto flex flex-col gap-16 relative overflow-hidden">
      
      {/* Decorative Edgy Logo Art */}
      <motion.div 
        initial={{ opacity: 0, x: 50 }}
        whileInView={{ opacity: 0.15, x: 0 }}
        viewport={{ once: true, margin: "-100px" }}
        transition={{ duration: 1.5, ease: "easeOut" }}
        className="absolute right-0 top-0 w-[400px] md:w-[600px] pointer-events-none translate-x-1/4 md:translate-x-1/3 -translate-y-12 md:-translate-y-24 z-0 mix-blend-screen"
      >
        <img src="/images/logo.png" alt="BRKN Tattoos Art" className="w-full h-auto object-contain drop-shadow-[0_0_15px_rgba(255,255,255,0.1)]" />
      </motion.div>

      <div className="flex flex-col gap-4 relative z-10">
        <h2 className="text-4xl sm:text-6xl font-serif text-bone uppercase tracking-widest leading-none">
          Initiation
        </h2>
        <p className="text-bone/50 font-sans tracking-widest uppercase text-sm">
          Submit your vision. We will reach out if it aligns.
        </p>
      </div>

      <div className="relative min-h-[500px] z-10">
        {/* Verification Wave Shatter */}
        <AnimatePresence>
          {!isVerified && (
            <motion.div 
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, scale: 1.1, filter: "blur(20px)", transition: { duration: 0.8, ease: "anticipate" } }}
              className="absolute inset-0 flex flex-col items-center justify-center bg-void border border-accent-blood p-8 z-20 text-center"
            >
              <h3 className="text-2xl font-serif text-accent-blood mb-6 uppercase tracking-widest">Age Gate</h3>
              <p className="text-bone/70 font-sans tracking-widest text-sm mb-12">
                You must be 18 years of age or older to enter the parlor.
              </p>
              <motion.button 
                onClick={handleVerification}
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                transition={heavyPhysics}
                className="border border-bone text-bone px-8 py-4 font-sans uppercase tracking-[0.2em] hover:bg-bone hover:text-void transition-colors duration-300"
              >
                I am 18 or older
              </motion.button>
            </motion.div>
          )}
        </AnimatePresence>

        {/* The Actual Form with Staggered Cascade */}
        {isVerified && (
          <motion.form 
            variants={container}
            initial="hidden"
            animate="show"
            className="flex flex-col gap-8 w-full relative z-10"
            onSubmit={async (e) => {
              e.preventDefault();
              const form = e.currentTarget;
              const formData = new FormData(form);
              const data = Object.fromEntries(formData.entries());
              
              const btn = form.querySelector('button[type="submit"]') as HTMLButtonElement;
              const originalText = btn.innerText;
              btn.innerText = "Transmitting...";
              btn.disabled = true;

              try {
                const res = await fetch('/api/contact', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify(data)
                });
                if (res.ok) {
                  btn.innerText = "Request Received";
                  form.reset();
                } else {
                  btn.innerText = "Transmission Failed";
                  setTimeout(() => { btn.innerText = originalText; btn.disabled = false; }, 3000);
                }
              } catch (err) {
                btn.innerText = "Transmission Failed";
                setTimeout(() => { btn.innerText = originalText; btn.disabled = false; }, 3000);
              }
            }}
          >
            {/* Honeypot field for spam protection */}
            <input 
              type="text" 
              name="website_url" 
              className="opacity-0 absolute top-0 left-0 h-0 w-0 z-[-1]" 
              tabIndex={-1} 
              autoComplete="off" 
            />

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <motion.div variants={item} className="flex flex-col gap-2 relative group">
                <label className="text-xs uppercase tracking-[0.2em] text-bone/50 transition-colors group-focus-within:text-accent-gold">Full Name</label>
                <input type="text" name="name" autoComplete="name" className="bg-transparent border-b border-bone/20 focus:border-transparent outline-none py-2 text-bone font-sans transition-colors duration-300 peer" required />
                <span className="absolute bottom-0 left-1/2 w-0 h-[1px] bg-accent-gold transition-all duration-500 ease-out peer-focus:w-full peer-focus:left-0"></span>
              </motion.div>
              
              <motion.div variants={item} className="flex flex-col gap-2 relative group">
                <label className="text-xs uppercase tracking-[0.2em] text-bone/50 transition-colors group-focus-within:text-accent-gold">Email</label>
                <input type="email" name="email" autoComplete="email" className="bg-transparent border-b border-bone/20 focus:border-transparent outline-none py-2 text-bone font-sans transition-colors duration-300 peer" required />
                <span className="absolute bottom-0 left-1/2 w-0 h-[1px] bg-accent-gold transition-all duration-500 ease-out peer-focus:w-full peer-focus:left-0"></span>
              </motion.div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <motion.div variants={item} className="flex flex-col gap-2 relative group">
                <label className="text-xs uppercase tracking-[0.2em] text-bone/50 transition-colors group-focus-within:text-accent-gold">Instagram Handle</label>
                <input type="text" name="instagram" placeholder="@" className="bg-transparent border-b border-bone/20 focus:border-transparent outline-none py-2 text-bone font-sans transition-colors duration-300 peer" />
                <span className="absolute bottom-0 left-1/2 w-0 h-[1px] bg-accent-gold transition-all duration-500 ease-out peer-focus:w-full peer-focus:left-0"></span>
              </motion.div>

              <motion.div variants={item} className="flex flex-col gap-2 relative group">
                <label className="text-xs uppercase tracking-[0.2em] text-bone/50 transition-colors group-focus-within:text-accent-gold">Body Placement</label>
                <input type="text" name="placement" className="bg-transparent border-b border-bone/20 focus:border-transparent outline-none py-2 text-bone font-sans transition-colors duration-300 peer" required />
                <span className="absolute bottom-0 left-1/2 w-0 h-[1px] bg-accent-gold transition-all duration-500 ease-out peer-focus:w-full peer-focus:left-0"></span>
              </motion.div>
            </div>

            <motion.div variants={item} className="flex flex-col gap-2 relative group">
              <label className="text-xs uppercase tracking-[0.2em] text-bone/50 transition-colors group-focus-within:text-accent-gold">The Vision (Concept)</label>
              <textarea name="concept" rows={4} className="bg-transparent border-b border-bone/20 focus:border-transparent outline-none py-2 text-bone font-sans transition-colors duration-300 resize-none peer" required></textarea>
              <span className="absolute bottom-0 left-1/2 w-0 h-[1px] bg-accent-gold transition-all duration-500 ease-out peer-focus:w-full peer-focus:left-0"></span>
            </motion.div>

            <motion.div variants={item} className="flex flex-col gap-2 group relative">
              <label className="text-xs uppercase tracking-[0.2em] text-bone/50">Reference Links (Optional)</label>
              <input 
                type="text" 
                name="reference_url"
                placeholder="Paste a link to a Pinterest board, Google Drive, or Instagram post"
                className="bg-transparent border-b border-bone/20 focus:border-transparent outline-none py-2 text-bone font-sans transition-colors duration-300 peer text-sm" 
              />
              <span className="absolute bottom-0 left-1/2 w-0 h-[1px] bg-accent-gold transition-all duration-500 ease-out peer-focus:w-full peer-focus:left-0"></span>
            </motion.div>

            <motion.button 
              variants={item}
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.95 }}
              transition={heavyPhysics}
              className="mt-8 bg-bone text-void py-6 uppercase font-sans tracking-[0.3em] font-bold hover:bg-accent-gold transition-colors duration-500 disabled:opacity-50 disabled:cursor-not-allowed"
              type="submit"
            >
              Submit Request
            </motion.button>
          </motion.form>
        )}
      </div>
    </section>
  )
}
