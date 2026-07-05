'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { useState } from 'react'
import imageCompression from 'browser-image-compression'
import { heavyPhysics } from '../motion/MotionWrapper'

const MAX_FILES = 4

export default function BookingForm() {
  const [isVerified, setIsVerified] = useState(false)
  const [files, setFiles] = useState<File[]>([])

  const handleVerification = (e: React.FormEvent) => {
    e.preventDefault()
    setIsVerified(true)
  }

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selected = Array.from(e.target.files ?? []).slice(0, MAX_FILES)
    setFiles(selected)
  }

  // Compress an image in the browser and return a Resend-ready attachment
  const compressToAttachment = async (file: File) => {
    const compressed = await imageCompression(file, {
      maxSizeMB: 1,
      maxWidthOrHeight: 1600,
      useWebWorker: true,
    })
    const dataUrl = await imageCompression.getDataUrlFromFile(compressed)
    return { filename: file.name, content: dataUrl.split(',')[1] }
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
              const data = Object.fromEntries(formData.entries()) as Record<string, unknown>;
              // The file input is handled separately via compression, not the raw FormData entry.
              delete data.references;

              const btn = form.querySelector('button[type="submit"]') as HTMLButtonElement;
              const originalText = btn.innerText;
              btn.disabled = true;

              try {
                if (files.length > 0) {
                  btn.innerText = "Compressing...";
                  data.attachments = await Promise.all(files.map(compressToAttachment));
                }

                btn.innerText = "Transmitting...";
                const res = await fetch('/api/contact', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify(data)
                });
                if (res.ok) {
                  btn.innerText = "Request Received";
                  form.reset();
                  setFiles([]);
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
                <label className="text-xs uppercase tracking-[0.2em] text-bone/50 transition-colors group-focus-within:text-accent-gold">Phone Number</label>
                <input type="tel" name="phone" autoComplete="tel" placeholder="(555) 555-5555" className="bg-transparent border-b border-bone/20 focus:border-transparent outline-none py-2 text-bone font-sans transition-colors duration-300 peer" />
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

            <motion.div variants={item} className="flex flex-col gap-2">
              <label className="text-xs uppercase tracking-[0.2em] text-bone/50">Reference Images (Optional)</label>
              <input
                type="file"
                name="references"
                accept="image/*"
                multiple
                onChange={handleFileChange}
                className="text-sm text-bone/70 font-sans file:mr-4 file:border file:border-bone/20 file:bg-transparent file:text-bone/70 file:px-4 file:py-2 file:uppercase file:tracking-[0.2em] file:text-xs file:cursor-pointer hover:file:border-accent-gold hover:file:text-accent-gold file:transition-colors"
              />
              <span className="text-[10px] uppercase tracking-[0.2em] text-bone/30">
                {files.length > 0
                  ? `${files.length} image${files.length > 1 ? 's' : ''} selected${files.length === MAX_FILES ? ' (max)' : ''} — compressed automatically`
                  : `Up to ${MAX_FILES} images — compressed automatically`}
              </span>
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
