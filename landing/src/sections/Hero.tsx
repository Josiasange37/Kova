"use client";

import { motion, useScroll, useTransform } from "framer-motion";
import Image from "next/image";
import Link from "next/link";
import { useState, useEffect } from "react";
import { ThemeToggle } from "@/components/ThemeToggle";

// User will replace these images
const HERO_IMAGE = "/hero-main.png";        // Main center image (person with glasses)
const CARD_IMAGE_1 = "/card-1.png";         // Right side card 1
const CARD_IMAGE_2 = "/card-2.png";         // Right side card 2

export function Hero() {
  const [scrolled, setScrolled] = useState(false);
  const { scrollY } = useScroll();

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 100);
    };
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <section className="relative min-h-screen bg-[#f5f5f5] dark:bg-[#0a0a0a] overflow-hidden transition-colors duration-500">
      {/* Grid overlay */}
      <div 
        className="absolute inset-0 pointer-events-none"
        style={{
          backgroundImage: `
            linear-gradient(rgba(0,0,0,0.03) 1px, transparent 1px),
            linear-gradient(90deg, rgba(0,0,0,0.03) 1px, transparent 1px)
          `,
          backgroundSize: '60px 60px'
        }}
      />
      {/* Dark mode grid overlay */}
      <div 
        className="absolute inset-0 pointer-events-none opacity-0 dark:opacity-100 transition-opacity duration-500"
        style={{
          backgroundImage: `
            linear-gradient(rgba(255,255,255,0.03) 1px, transparent 1px),
            linear-gradient(90deg, rgba(255,255,255,0.03) 1px, transparent 1px)
          `,
          backgroundSize: '60px 60px'
        }}
      />

      {/* Collapsible Navigation */}
      <motion.div 
        className="fixed top-0 left-0 right-0 z-50 flex justify-center pt-4 px-4"
        initial={{ y: -100 }}
        animate={{ y: 0 }}
        transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
      >
        <motion.div
          className="flex items-center gap-1 overflow-hidden"
          animate={{
            width: scrolled ? "auto" : "100%",
            maxWidth: scrolled ? "500px" : "1400px",
            paddingLeft: scrolled ? "8px" : "0px",
            paddingRight: scrolled ? "8px" : "0px",
            paddingTop: scrolled ? "6px" : "0px",
            paddingBottom: scrolled ? "6px" : "0px",
            backgroundColor: scrolled ? "rgba(255,255,255,0.9)" : "transparent",
            backdropFilter: scrolled ? "blur(20px)" : "blur(0px)",
            borderRadius: scrolled ? "9999px" : "0px",
            boxShadow: scrolled ? "0 4px 30px rgba(0,0,0,0.1)" : "0 0 0 rgba(0,0,0,0)",
          }}
          transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
          style={{
            marginLeft: scrolled ? "auto" : "0",
            marginRight: scrolled ? "auto" : "0",
          }}
        >
          {/* Logo - shrinks when collapsed */}
          <motion.div
            animate={{
              scale: scrolled ? 0.85 : 1,
              marginRight: scrolled ? "4px" : "auto",
            }}
            transition={{ duration: 0.4 }}
            className={scrolled ? "" : "flex-1"}
          >
            <Link href="/" className="flex items-center pl-2">
              <span className="text-xl font-bold text-gray-900 dark:text-white tracking-tight">S2</span>
            </Link>
          </motion.div>

          {/* Desktop Nav Links - fade out when collapsed */}
          <motion.nav 
            className="hidden md:flex items-center gap-6"
            animate={{
              opacity: scrolled ? 0 : 1,
              x: scrolled ? -20 : 0,
              pointerEvents: scrolled ? "none" : "auto",
            }}
            transition={{ duration: 0.3 }}
          >
            {["SOLUTION", "PROCESS", "CONTACT", "JOIN"].map((item) => (
              <Link
                key={item}
                href={`#${item.toLowerCase()}`}
                className="text-xs font-medium text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition-colors tracking-wide"
              >
                {item}
              </Link>
            ))}
          </motion.nav>

          {/* Collapsed Nav Items - shown only when scrolled */}
          <motion.div
            className="hidden md:flex items-center gap-1"
            initial={{ opacity: 0, x: 20 }}
            animate={{
              opacity: scrolled ? 1 : 0,
              x: scrolled ? 0 : 20,
              pointerEvents: scrolled ? "auto" : "none",
            }}
            transition={{ duration: 0.3, delay: scrolled ? 0.1 : 0 }}
          >
            {["Features", "How it Works", "Docs"].map((item) => (
              <Link
                key={item}
                href={`#${item.toLowerCase().replace(/ /g, "-")}`}
                className="px-3 py-2 text-sm font-medium text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white transition-colors rounded-full hover:bg-gray-100/50 dark:hover:bg-white/10"
              >
                {item}
              </Link>
            ))}
          </motion.div>

          {/* CTA Button */}
          <motion.div
            animate={{
              scale: scrolled ? 1 : 0.9,
              marginLeft: scrolled ? "4px" : "0px",
            }}
            transition={{ duration: 0.4 }}
            className={scrolled ? "" : "flex-1 flex justify-end"}
          >
            <Link
              href="#cta"
              className={`px-5 py-2.5 bg-indigo-600 text-white text-sm font-semibold rounded-full hover:bg-indigo-700 transition-colors shadow-md shadow-indigo-500/20 ${scrolled ? "" : "mr-2"}`}
            >
              {scrolled ? "Download" : "Get Started"}
            </Link>
          </motion.div>

          {/* Theme Toggle - visible when collapsed */}
          <motion.div
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{
              opacity: scrolled ? 1 : 0,
              scale: scrolled ? 1 : 0.8,
              pointerEvents: scrolled ? "auto" : "none",
            }}
            transition={{ duration: 0.3, delay: scrolled ? 0.2 : 0 }}
          >
            <ThemeToggle />
          </motion.div>
        </motion.div>
      </motion.div>

      {/* Spacer for fixed navbar */}
      <div className="h-20" />

      {/* Main Content */}
      <div className="relative z-10 min-h-screen flex items-center justify-center px-8 lg:px-16">
        <div className="w-full max-w-[1400px] mx-auto grid grid-cols-12 gap-4 items-center">
          
          {/* Left Text */}
          <motion.div 
            initial={{ opacity: 0, x: -30 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, delay: 0.2 }}
            className="col-span-12 md:col-span-3 flex justify-center md:justify-end"
          >
            <h1 className="text-3xl md:text-4xl lg:text-5xl font-light text-gray-900 dark:text-white tracking-tight">
              Protection
            </h1>
          </motion.div>

          {/* Center Image */}
          <motion.div 
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 1, delay: 0.4 }}
            className="col-span-12 md:col-span-6 flex justify-center"
          >
            <div className="relative w-full max-w-[500px] aspect-[3/4]">
              <Image
                src={HERO_IMAGE}
                alt="Hero"
                fill
                className="object-contain"
                priority
              />
              {/* Fallback gradient placeholder */}
              <div className="absolute inset-0 bg-gradient-to-b from-transparent via-gray-200/50 to-transparent flex items-center justify-center -z-10">
                <span className="text-gray-400 dark:text-gray-600 text-sm">Replace with: /hero-main.png</span>
              </div>
            </div>
          </motion.div>

          {/* Right Side: Text + Cards */}
          <motion.div 
            initial={{ opacity: 0, x: 30 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, delay: 0.6 }}
            className="col-span-12 md:col-span-3 flex flex-col items-center md:items-start gap-8"
          >
            {/* Right text */}
            <h1 className="text-3xl md:text-4xl lg:text-5xl font-light text-gray-900 dark:text-white tracking-tight">
              is a limit
            </h1>

            {/* Side Cards */}
            <div className="flex flex-col gap-4 mt-4">
              {/* Card 1 */}
              <div className="group relative w-32 h-24 rounded-xl overflow-hidden bg-gray-200 shadow-lg">
                <Image
                  src={CARD_IMAGE_1}
                  alt="Card 1"
                  fill
                  className="object-cover"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
                <div className="absolute bottom-2 left-2 right-2">
                  <p className="text-[8px] text-white/80 uppercase tracking-wide leading-tight">
                    Augmented. Amplified. Alive.
                  </p>
                </div>
                {/* Placeholder text */}
                <div className="absolute inset-0 flex items-center justify-center -z-10">
                  <span className="text-gray-400 dark:text-gray-600 text-[10px]">/card-1.png</span>
                </div>
              </div>

              {/* Card 2 */}
              <div className="group relative w-32 h-24 rounded-xl overflow-hidden bg-gray-200 shadow-lg">
                <Image
                  src={CARD_IMAGE_2}
                  alt="Card 2"
                  fill
                  className="object-cover"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
                <div className="absolute bottom-2 left-2 right-2">
                  <p className="text-[8px] text-white/80 uppercase tracking-wide leading-tight">
                    The mind has no ceiling
                  </p>
                </div>
                {/* Placeholder text */}
                <div className="absolute inset-0 flex items-center justify-center -z-10">
                  <span className="text-gray-400 dark:text-gray-600 text-[10px]">/card-2.png</span>
                </div>
              </div>
            </div>
          </motion.div>
        </div>
      </div>

      {/* Bottom Left CTA */}
      <motion.div 
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, delay: 0.8 }}
        className="absolute bottom-12 left-8 lg:left-16 z-20"
      >
        <Link
          href="#features"
          className="group flex items-center gap-3 px-6 py-3 bg-gray-900 text-white text-sm font-medium rounded-full hover:bg-gray-800 transition-colors"
        >
          <span>ENTER THE SYSTEM</span>
          <svg 
            className="w-4 h-4 transition-transform group-hover:translate-x-1" 
            fill="none" 
            stroke="currentColor" 
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 8l4 4m0 0l-4 4m4-4H3" />
          </svg>
        </Link>
      </motion.div>
    </section>
  );
}
