import Hero from '@/components/sections/Hero'
import InstagramCTA from '@/components/sections/InstagramCTA'
import BookingForm from '@/components/sections/BookingForm'
import FallingGallery from '@/components/sections/FallingGallery'

export default function Home() {
  return (
    <main className="min-h-screen selection:bg-accent-blood selection:text-bone relative">
      {/* Global Edgy Victorian Dungeon Background */}
      <div 
        className="fixed inset-0 z-0 bg-cover bg-center bg-no-repeat opacity-15 grayscale pointer-events-none"
        style={{ backgroundImage: "url('/images/dungeon_bg_1783205943824.png')" }}
      />
      
      {/* 
        The noise overlay is handled globally in layout.tsx.
        Each section handles its own viewport padding and max-widths.
      */}
      <Hero />
      <FallingGallery />
      <BookingForm />
      <InstagramCTA />
      
      {/* Minimal Footer */}
      <footer className="w-full py-12 text-center border-t border-bone/10 mt-24">
        <p className="text-bone/30 font-sans text-xs uppercase tracking-widest">
          © {new Date().getFullYear()} BRKN Tattoos LA. The Underground.
        </p>
      </footer>
    </main>
  )
}
