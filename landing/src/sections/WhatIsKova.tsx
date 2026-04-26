"use client";

import { motion, useInView } from "framer-motion";
import { useRef } from "react";
import Image from "next/image";

const leftFeatures = [
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
      </svg>
    ),
    title: "Zero-Knowledge Security",
    description: "AES-256 encryption ensures your data remains private. Not even KOVA can access your information.",
    color: "#3B82F6",
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
      </svg>
    ),
    title: "Stealth Mode",
    description: "Runs invisibly as a system service. Undetectable and survives app killers, reboots, and cache clears.",
    color: "#6366F1",
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M13 10V3L4 14h7v7l9-11h-7z" />
      </svg>
    ),
    title: "OEM Unkillable",
    description: "Counter-attacks aggressive battery optimization on MIUI, ColorOS, EMUI with persistent wakelocks.",
    color: "#A855F7",
  },
];

const rightFeatures = [
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
    title: "Real-Time Monitoring",
    description: "Captures activity from 35+ apps including WhatsApp, TikTok, Instagram, Snap, and incognito browsers.",
    color: "#10B981",
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
      </svg>
    ),
    title: "Instant Alerts",
    description: "Get notified immediately when protection is tampered with, apps are uninstalled, or ADB is attempted.",
    color: "#F59E0B",
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z" />
      </svg>
    ),
    title: "Open Source",
    description: "Fully auditable code on GitHub. Free forever with no subscriptions, no ads, and no data collection.",
    color: "#EF4444",
  },
];

export function WhatIsKova() {
  const containerRef = useRef<HTMLDivElement>(null);
  const isInView = useInView(containerRef, { once: true, margin: "-100px" });

  return (
    <section ref={containerRef} className="relative py-24 lg:py-32 bg-[#f5f5f5] dark:bg-[#0a0a0a] overflow-hidden transition-colors duration-500">
      {/* Grid overlay */}
      <div 
        className="absolute inset-0 pointer-events-none opacity-50"
        style={{
          backgroundImage: `linear-gradient(rgba(0,0,0,0.02) 1px, transparent 1px), linear-gradient(90deg, rgba(0,0,0,0.02) 1px, transparent 1px)`,
          backgroundSize: '60px 60px'
        }}
      />

      <div className="relative z-10 max-w-7xl mx-auto px-6 lg:px-8">
        {/* Section Header */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.8 }}
          className="text-center mb-16 lg:mb-24"
        >
          <span className="text-xs font-medium text-gray-400 dark:text-gray-500 uppercase tracking-widest mb-4 block">
            What is KOVA
          </span>
          <h2 className="text-4xl md:text-5xl lg:text-6xl font-light text-gray-900 dark:text-white tracking-tight">
            Next-Gen <span className="font-semibold">Protection</span>
          </h2>
          <p className="mt-6 text-lg text-gray-500 dark:text-gray-400 max-w-2xl mx-auto">
            KOVA is an advanced child monitoring system designed for the modern digital age. 
            Invisible, encrypted, and impossible to disable.
          </p>
        </motion.div>

        {/* Main Layout */}
        <div className="relative grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-4 items-center">
          
          {/* Left Features */}
          <div className="lg:col-span-3 flex flex-col gap-8 lg:gap-12">
            {leftFeatures.map((feature, i) => (
              <motion.div
                key={feature.title}
                initial={{ opacity: 0, x: -30 }}
                animate={isInView ? { opacity: 1, x: 0 } : {}}
                transition={{ duration: 0.6, delay: 0.2 + i * 0.15 }}
                className="relative group text-right lg:text-right"
              >
                {/* Connection line to center */}
                <div className="hidden lg:block absolute top-1/2 -right-8 w-16 h-px bg-gray-300">
                  <div className="absolute right-0 top-1/2 -translate-y-1/2 w-2 h-2 rounded-full bg-gray-400" />
                </div>

                <div className="flex items-start gap-4 lg:flex-row-reverse">
                  <div 
                    className="w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0 transition-transform group-hover:scale-110"
                    style={{ backgroundColor: `${feature.color}15`, color: feature.color }}
                  >
                    {feature.icon}
                  </div>
                  <div>
                    <h3 className="text-sm font-semibold text-gray-900 dark:text-white mb-1">
                      {feature.title}
                    </h3>
                    <p className="text-xs text-gray-500 dark:text-gray-400 leading-relaxed">
                      {feature.description}
                    </p>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>

          {/* Center Image */}
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={isInView ? { opacity: 1, scale: 1 } : {}}
            transition={{ duration: 0.8, delay: 0.4 }}
            className="lg:col-span-6 flex justify-center relative"
          >
            {/* Connection lines container */}
            <div className="absolute inset-0 pointer-events-none hidden lg:block">
              {/* Left lines */}
              {leftFeatures.map((_, i) => (
                <div
                  key={`left-${i}`}
                  className="absolute top-1/2 right-full w-[calc(50%-60px)] h-px bg-gray-200"
                  style={{ top: `${20 + i * 30}%` }}
                >
                  <div className="absolute right-0 top-1/2 -translate-y-1/2 w-1.5 h-1.5 rounded-full bg-gray-300" />
                  <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1.5 h-1.5 rounded-full bg-gray-300" />
                </div>
              ))}
              {/* Right lines */}
              {rightFeatures.map((_, i) => (
                <div
                  key={`right-${i}`}
                  className="absolute top-1/2 left-full w-[calc(50%-60px)] h-px bg-gray-200"
                  style={{ top: `${20 + i * 30}%` }}
                >
                  <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1.5 h-1.5 rounded-full bg-gray-300" />
                  <div className="absolute right-0 top-1/2 -translate-y-1/2 w-1.5 h-1.5 rounded-full bg-gray-300" />
                </div>
              ))}
            </div>

            {/* Image container */}
            <div className="relative w-full max-w-[400px] aspect-square">
              <div className="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 rounded-3xl flex items-center justify-center">
                <Image
                  src="/kova-device.png"
                  alt="KOVA Device"
                  fill
                  className="object-contain p-8"
                />
                {/* Placeholder text */}
                <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                  <span className="text-gray-400 dark:text-gray-600 text-sm">Replace: /kova-device.png</span>
                </div>
              </div>
              
              {/* Decorative ring */}
              <div className="absolute -inset-4 border border-gray-200 rounded-[2rem] -z-10" />
              <div className="absolute -inset-8 border border-gray-100 rounded-[2.5rem] -z-10" />
            </div>
          </motion.div>

          {/* Right Features */}
          <div className="lg:col-span-3 flex flex-col gap-8 lg:gap-12">
            {rightFeatures.map((feature, i) => (
              <motion.div
                key={feature.title}
                initial={{ opacity: 0, x: 30 }}
                animate={isInView ? { opacity: 1, x: 0 } : {}}
                transition={{ duration: 0.6, delay: 0.2 + i * 0.15 }}
                className="relative group"
              >
                {/* Connection line to center */}
                <div className="hidden lg:block absolute top-1/2 -left-8 w-16 h-px bg-gray-300">
                  <div className="absolute left-0 top-1/2 -translate-y-1/2 w-2 h-2 rounded-full bg-gray-400" />
                </div>

                <div className="flex items-start gap-4">
                  <div 
                    className="w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0 transition-transform group-hover:scale-110"
                    style={{ backgroundColor: `${feature.color}15`, color: feature.color }}
                  >
                    {feature.icon}
                  </div>
                  <div>
                    <h3 className="text-sm font-semibold text-gray-900 dark:text-white mb-1">
                      {feature.title}
                    </h3>
                    <p className="text-xs text-gray-500 dark:text-gray-400 leading-relaxed">
                      {feature.description}
                    </p>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
