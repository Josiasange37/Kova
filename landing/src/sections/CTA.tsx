"use client";

import { useRef } from "react";
import { motion, useInView } from "framer-motion";
import Link from "next/link";
import Image from "next/image";

export function CTA() {
  const containerRef = useRef<HTMLDivElement>(null);
  const isInView = useInView(containerRef, { once: true, margin: "-100px" });

  return (
    <section
      id="cta"
      ref={containerRef}
      className="relative py-32 lg:py-48 bg-[#f5f5f5] dark:bg-[#0a0a0a] overflow-hidden transition-colors duration-500"
    >
      {/* Top geometric decoration */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[600px] h-[200px] pointer-events-none">
        <Image
          src="/cta-top-shape.png"
          alt=""
          fill
          className="object-contain object-bottom opacity-80"
        />
        <div className="absolute inset-0 flex items-end justify-center pb-4">
          <span className="text-gray-300 dark:text-gray-700 text-xs">/cta-top-shape.png</span>
        </div>
      </div>

      {/* Bottom geometric decoration */}
      <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-[600px] h-[200px] pointer-events-none">
        <Image
          src="/cta-bottom-shape.png"
          alt=""
          fill
          className="object-contain object-top opacity-80"
        />
        <div className="absolute inset-0 flex items-start justify-center pt-4">
          <span className="text-gray-300 text-xs">/cta-bottom-shape.png</span>
        </div>
      </div>

      <div className="relative z-10 max-w-2xl mx-auto px-6 lg:px-8 text-center">
        {/* Badge */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6 }}
          className="mb-6"
        >
          <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-amber-100 text-amber-700 text-xs font-medium">
            <svg className="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
            </svg>
            Free & Open Source
          </span>
        </motion.div>

        {/* Headline */}
        <motion.h2
          initial={{ opacity: 0, y: 30 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.8, delay: 0.1 }}
          className="text-4xl md:text-5xl lg:text-6xl font-semibold text-gray-900 dark:text-white tracking-tight mb-6"
        >
          Protect What
          <br />
          Matters Most
        </motion.h2>

        {/* Description */}
        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6, delay: 0.2 }}
          className="text-base md:text-lg text-gray-500 dark:text-gray-400 max-w-lg mx-auto mb-10 leading-relaxed"
        >
          Deploy enterprise-grade protection in minutes. Monitor 35+ apps, 
          receive instant alerts, and keep your family safe with zero-knowledge encryption.
        </motion.p>

        {/* CTA Button */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6, delay: 0.3 }}
        >
          <Link
            href="#download"
            className="inline-flex items-center px-8 py-4 bg-gray-900 text-white text-sm font-medium rounded-full hover:bg-gray-800 transition-colors shadow-lg shadow-gray-900/20"
          >
            Get Started
          </Link>
        </motion.div>

        {/* Trust text */}
        <motion.p
          initial={{ opacity: 0 }}
          animate={isInView ? { opacity: 1 } : {}}
          transition={{ duration: 0.6, delay: 0.4 }}
          className="mt-8 text-xs text-gray-400 dark:text-gray-600"
        >
          No account required. Free forever. No data collection.
        </motion.p>
      </div>
    </section>
  );
}
