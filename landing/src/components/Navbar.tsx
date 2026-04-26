"use client";

import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";

export function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const handler = () => setScrolled(window.scrollY > 50);
    window.addEventListener("scroll", handler, { passive: true });
    return () => window.removeEventListener("scroll", handler);
  }, []);

  return (
    <motion.nav
      initial={{ y: -100, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
      className={`fixed top-4 left-1/2 -translate-x-1/2 z-50 transition-all duration-500 rounded-full ${
        scrolled
          ? "bg-white/90 backdrop-blur-xl shadow-lg shadow-black/5"
          : "bg-white/80 backdrop-blur-md"
      }`}
    >
      <div className="flex items-center gap-2 px-2 py-2">
        {/* Logo */}
        <Link href="/" className="flex items-center gap-2 pl-3 pr-2">
          <div className="w-8 h-8 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center">
            <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
          </div>
        </Link>

        {/* Centered Desktop links */}
        <div className="hidden md:flex items-center gap-1">
          <Link
            href="#features"
            className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900 transition-colors rounded-full hover:bg-gray-100/50"
          >
            Features
          </Link>
          <Link
            href="#story"
            className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900 transition-colors rounded-full hover:bg-gray-100/50"
          >
            How it Works
          </Link>
          <Link
            href="#docs"
            className="px-4 py-2 text-sm font-medium text-gray-600 bg-gray-100/80 rounded-full hover:bg-gray-200/80 transition-colors"
          >
            Documentation
          </Link>
        </div>

        {/* CTA Button */}
        <Link
          href="#cta"
          className="ml-2 px-5 py-2.5 bg-indigo-600 text-white text-sm font-semibold rounded-full hover:bg-indigo-700 transition-colors shadow-md shadow-indigo-500/20"
        >
          Download
        </Link>

        {/* Mobile menu button */}
        <button
          onClick={() => setMobileOpen(!mobileOpen)}
          className="md:hidden flex flex-col gap-1 p-2 ml-1"
          aria-label="Toggle menu"
        >
          <motion.span
            animate={{ rotate: mobileOpen ? 45 : 0, y: mobileOpen ? 5 : 0 }}
            className="w-5 h-0.5 bg-gray-700 block origin-center"
          />
          <motion.span
            animate={{ opacity: mobileOpen ? 0 : 1 }}
            className="w-5 h-0.5 bg-gray-700 block"
          />
          <motion.span
            animate={{ rotate: mobileOpen ? -45 : 0, y: mobileOpen ? -5 : 0 }}
            className="w-5 h-0.5 bg-gray-700 block origin-center"
          />
        </button>
      </div>

      {/* Mobile menu */}
      <AnimatePresence>
        {mobileOpen && (
          <motion.div
            initial={{ opacity: 0, y: -10, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -10, scale: 0.95 }}
            transition={{ duration: 0.2 }}
            className="md:hidden absolute top-full left-0 right-0 mt-2 bg-white/95 backdrop-blur-xl rounded-2xl shadow-xl shadow-black/10 border border-gray-100 overflow-hidden"
          >
            <div className="p-2 flex flex-col gap-1">
              {[
                { label: "Features", href: "#features" },
                { label: "How it Works", href: "#story" },
                { label: "Documentation", href: "#docs" },
              ].map((link, i) => (
                <motion.div
                  key={link.label}
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: i * 0.05 }}
                >
                  <Link
                    href={link.href}
                    onClick={() => setMobileOpen(false)}
                    className="block px-4 py-3 text-sm font-medium text-gray-700 hover:text-gray-900 hover:bg-gray-50 rounded-xl transition-colors"
                  >
                    {link.label}
                  </Link>
                </motion.div>
              ))}
              <motion.div
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.15 }}
                className="pt-1 mt-1 border-t border-gray-100"
              >
                <Link
                  href="#cta"
                  onClick={() => setMobileOpen(false)}
                  className="block mx-1 mb-1 py-3 px-4 bg-indigo-600 text-white text-sm font-semibold rounded-xl text-center hover:bg-indigo-700 transition-colors"
                >
                  Download Now
                </Link>
              </motion.div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.nav>
  );
}
