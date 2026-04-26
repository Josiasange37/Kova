"use client";

import { motion, useInView } from "framer-motion";
import { useRef } from "react";
import Image from "next/image";

const features = [
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" />
      </svg>
    ),
    label: "Offline First",
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
      </svg>
    ),
    label: "Zero Knowledge",
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
      </svg>
    ),
    label: "Stealth Mode",
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
      </svg>
    ),
    label: "Tamper Proof",
  },
];

export function WhatKovaDoes() {
  const containerRef = useRef<HTMLDivElement>(null);
  const isInView = useInView(containerRef, { once: true, margin: "-100px" });

  return (
    <section ref={containerRef} className="relative py-16 lg:py-24 bg-[#f5f5f5] dark:bg-[#0a0a0a] overflow-hidden transition-colors duration-500">
      {/* Topographic decoration */}
      <div className="absolute top-0 right-0 w-64 h-64 opacity-30">
        <svg viewBox="0 0 200 200" className="w-full h-full text-gray-300 dark:text-gray-700">
          {[...Array(8)].map((_, i) => (
            <ellipse
              key={i}
              cx="100"
              cy="100"
              rx={30 + i * 15}
              ry={20 + i * 10}
              fill="none"
              stroke="currentColor"
              strokeWidth="0.5"
            />
          ))}
        </svg>
      </div>
      <div className="absolute bottom-0 left-0 w-64 h-64 opacity-30 rotate-180">
        <svg viewBox="0 0 200 200" className="w-full h-full text-gray-300 dark:text-gray-700">
          {[...Array(8)].map((_, i) => (
            <ellipse
              key={i}
              cx="100"
              cy="100"
              rx={30 + i * 15}
              ry={20 + i * 10}
              fill="none"
              stroke="currentColor"
              strokeWidth="0.5"
            />
          ))}
        </svg>
      </div>

      <div className="relative z-10 max-w-5xl mx-auto px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 40 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.8 }}
          className="relative rounded-[2.5rem] overflow-hidden bg-gray-900"
        >
          {/* Background Image */}
          <div className="absolute inset-0">
            <Image
              src="/kova-action-bg.png"
              alt="Background"
              fill
              className="object-cover opacity-40"
            />
            {/* Gradient overlay */}
            <div className="absolute inset-0 bg-gradient-to-t from-gray-900 via-gray-900/80 to-gray-900/60" />
          </div>

          {/* Content */}
          <div className="relative z-10 px-8 lg:px-16 py-16 lg:py-24 text-center">
            {/* Title */}
            <motion.h2
              initial={{ opacity: 0, y: 20 }}
              animate={isInView ? { opacity: 1, y: 0 } : {}}
              transition={{ duration: 0.6, delay: 0.2 }}
              className="text-3xl md:text-4xl lg:text-5xl font-semibold text-white mb-6"
            >
              What KOVA Does
            </motion.h2>

            {/* Description */}
            <motion.p
              initial={{ opacity: 0, y: 20 }}
              animate={isInView ? { opacity: 1, y: 0 } : {}}
              transition={{ duration: 0.6, delay: 0.3 }}
              className="text-sm md:text-base text-gray-300 max-w-2xl mx-auto leading-relaxed mb-12"
            >
              KOVA silently monitors your child's digital activity across 35+ applications, 
              capturing messages, media, and screen time. All data is encrypted locally and 
              synced securely to the parent's dashboard only when you choose to connect. 
              Unlike other solutions, KOVA operates completely offline and cannot be 
              detected or disabled by the child.
            </motion.p>

            {/* Feature Icons */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={isInView ? { opacity: 1, y: 0 } : {}}
              transition={{ duration: 0.6, delay: 0.4 }}
              className="flex flex-wrap items-center justify-center gap-8 lg:gap-12"
            >
              {features.map((feature, i) => (
                <motion.div
                  key={feature.label}
                  initial={{ opacity: 0, scale: 0.8 }}
                  animate={isInView ? { opacity: 1, scale: 1 } : {}}
                  transition={{ duration: 0.4, delay: 0.5 + i * 0.1 }}
                  className="flex flex-col items-center gap-3"
                >
                  <div className="w-16 h-16 rounded-full bg-white flex items-center justify-center text-gray-900 hover:scale-110 transition-transform">
                    {feature.icon}
                  </div>
                  <span className="text-xs text-gray-400 font-medium">
                    {feature.label}
                  </span>
                </motion.div>
              ))}
            </motion.div>
          </div>

          {/* Placeholder text for image */}
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none -z-10">
            <span className="text-gray-600 dark:text-gray-500 text-sm">Replace: /kova-action-bg.png</span>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
