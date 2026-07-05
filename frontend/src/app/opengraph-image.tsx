import { ImageResponse } from 'next/og'
import { readFileSync } from 'fs'
import { join } from 'path'

export const alt = 'MR. BRKN Custom Studio'
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default async function Image() {
  // Read local image and convert to base64 to avoid fetch issues during build
  const imagePath = join(process.cwd(), 'public', 'images', 'mr_brkn.jpg')
  const imageData = readFileSync(imagePath)
  const imageBase64 = `data:image/jpeg;base64,${imageData.toString('base64')}`

  return new ImageResponse(
    (
      <div 
        style={{ 
          display: 'flex', 
          width: '100%', 
          height: '100%', 
          backgroundColor: '#0A0A0C', // bg-void-charcoal
          color: '#D4D4D4',           // text-bone
          overflow: 'hidden' 
        }}
      >
        {/* Left Side: Photo */}
        <div style={{ display: 'flex', width: '50%', height: '100%' }}>
          <img 
            src={imageBase64} 
            style={{ 
              width: '100%', 
              height: '100%', 
              objectFit: 'cover',
              filter: 'grayscale(100%) contrast(1.2)' // matching the dark aesthetic
            }} 
          />
        </div>
        
        {/* Right Side: Typography */}
        <div style={{ 
          display: 'flex', 
          flexDirection: 'column', 
          justifyContent: 'center', 
          padding: '80px', 
          width: '50%',
          fontFamily: 'sans-serif'
        }}>
          <h1 style={{ 
            fontSize: '84px', 
            margin: 0, 
            fontWeight: 'bold', 
            lineHeight: 1.1, 
            textTransform: 'uppercase' 
          }}>
            MR. BRKN
          </h1>
          <h2 style={{ 
            fontSize: '32px', 
            margin: '20px 0 0 0', 
            fontWeight: 'normal', 
            letterSpacing: '0.3em', 
            color: '#8A0303', // accent-blood
            textTransform: 'uppercase' 
          }}>
            Custom Studio
          </h2>
          <div style={{ 
            marginTop: '80px',
            width: '60px',
            height: '2px',
            backgroundColor: '#B89947' // accent-gold
          }} />
        </div>
      </div>
    ),
    { ...size }
  )
}
