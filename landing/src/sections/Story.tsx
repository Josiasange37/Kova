"use client";

import { useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";
import Image from "next/image";

const steps = [
  {
    number: "01",
    title: "Download & Install",
    description: "Download KOVA from GitHub and sideload the APK on your child's Android device. The installation process takes under 2 minutes and requires no technical expertise. Our guided setup walks you through each permission grant.",
    image: "/story-install.png",
    color: "#3B82F6",
  },
  {
    number: "02",
    title: "Grant Permissions",
    description: "Activate Device Admin and Accessibility permissions to enable full monitoring capabilities. These permissions allow KOVA to run as a system-level service, capture screen content, and detect app usage in real-time.",
    image: "/story-permissions.png",
    color: "#8B5CF6",
  },
  {
    number: "03",
    title: "Silent Operation",
    description: "Once activated, KOVA becomes completely invisible. No app icon, no notifications, no battery drain indicator. It runs 24/7 in the background capturing activity from WhatsApp, TikTok, Instagram, browsers, and 35+ other apps.",
    image: "/story-running.png",
    color: "#10B981",
  },
  {
    number: "04",
    title: "Secure Sync",
    description: "All captured data is encrypted with AES-256 on the device itself. When you connect to the parent dashboard, data syncs through a secure At-Least-Once delivery pipeline. Nothing is stored on our servers.",
    image: "/story-sync.png",
    color: "#F59E0B",
  },
];

export function Story() {
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end end"],
  });

  // Ball position transforms
  const ballY = useTransform(scrollYProgress, [0, 1], ["0%", "100%"]);
  const ballRotate = useTransform(scrollYProgress, [0, 1], [0, 720]);

  return (
    <section
      ref={containerRef}
      className="relative bg-[#f5f5f5] dark:bg-[#0a0a0a] transition-colors duration-500"
      style={{ height: `${steps.length * 150}vh` }}
    >
      <div className="sticky top-0 h-screen overflow-hidden">
        {/* Background grid */}
        <div 
          className="absolute inset-0 pointer-events-none opacity-50"
          style={{
            backgroundImage: `linear-gradient(rgba(0,0,0,0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(0,0,0,0.03) 1px, transparent 1px)`,
            backgroundSize: '60px 60px'
          }}
        />

        {/* Header */}
        <div className="absolute top-8 left-0 right-0 text-center z-20">
          <span className="text-xs font-medium text-gray-400 dark:text-gray-500 uppercase tracking-widest mb-2 block">
            The Journey
          </span>
          <h2 className="text-3xl md:text-4xl font-light text-gray-900 dark:text-white">
            How KOVA <span className="font-semibold">Works</span>
          </h2>
        </div>

        {/* Main content container */}
        <div className="relative h-full max-w-7xl mx-auto px-6 lg:px-8 flex">
          
          {/* Left side - Steps with ball track */}
          <div className="flex-1 relative py-32">
            {/* Vertical track line */}
            <div className="absolute left-8 lg:left-12 top-32 bottom-32 w-px bg-gray-200 dark:bg-gray-700" />
            
            {/* Rolling black ball */}
            <motion.div
              className="absolute left-8 lg:left-12 w-4 h-4 -ml-2 z-30"
              style={{ 
                top: ballY,
                rotate: ballRotate,
              }}
            >
              <div className="w-full h-full rounded-full bg-black shadow-lg">
                {/* Shine effect */}
                <div className="absolute top-1 left-1 w-1 h-1 rounded-full bg-white/30" />
              </div>
            </motion.div>

            {/* Step indicators on track */}
            <div className="absolute left-8 lg:left-12 top-32 bottom-32 flex flex-col justify-between py-2">
              {steps.map((_, i) => (
                <motion.div
                  key={i}
                  className="w-2 h-2 -ml-1 rounded-full border-2 border-gray-300 bg-white transition-colors duration-300"
                  style={{
                    backgroundColor: useTransform(
                      scrollYProgress,
                      [i / steps.length, (i + 0.5) / steps.length],
                      ["#ffffff", "#000000"]
                    ),
                    borderColor: useTransform(
                      scrollYProgress,
                      [i / steps.length, (i + 0.5) / steps.length],
                      ["#d1d5db", "#000000"]
                    ),
                  }}
                />
              ))}
            </div>

            {/* Steps content */}
            <div className="ml-20 lg:ml-24 space-y-[35vh] pt-[10vh]">
              {steps.map((step, i) => (
                <StepContent 
                  key={step.number} 
                  step={step} 
                  index={i}
                  scrollYProgress={scrollYProgress}
                />
              ))}
            </div>
          </div>

          {/* Right side - Images */}
          <div className="hidden lg:flex flex-1 items-center justify-center relative">
            <div className="relative w-full max-w-md aspect-[4/3] rounded-2xl overflow-hidden bg-gray-200 dark:bg-gray-800 shadow-2xl">
              {steps.map((step, i) => (
                <motion.div
                  key={step.image}
                  className="absolute inset-0"
                  style={{
                    opacity: useTransform(
                      scrollYProgress,
                      [i / steps.length, (i + 0.3) / steps.length, (i + 0.7) / steps.length, (i + 1) / steps.length],
                      [0, 1, 1, 0]
                    ),
                    scale: useTransform(
                      scrollYProgress,
                      [i / steps.length, (i + 0.3) / steps.length, (i + 0.7) / steps.length, (i + 1) / steps.length],
                      [0.9, 1, 1, 0.9]
                    ),
                    y: useTransform(
                      scrollYProgress,
                      [i / steps.length, (i + 0.3) / steps.length, (i + 0.7) / steps.length, (i + 1) / steps.length],
                      [50, 0, 0, -50]
                    ),
                  }}
                >
                  <Image
                    src={step.image}
                    alt={step.title}
                    fill
                    className="object-cover"
                  />
                  <div className="absolute inset-0 flex items-center justify-center bg-gray-100 dark:bg-gray-900 -z-10">
                    <span className="text-gray-400 dark:text-gray-500 text-sm">{step.image}</span>
                  </div>
                </motion.div>
              ))}
            </div>
          </div>
        </div>

        {/* Progress indicator */}
        <div className="absolute bottom-8 left-1/2 -translate-x-1/2 flex items-center gap-4">
          {steps.map((step, i) => (
            <motion.div
              key={i}
              className="h-1 rounded-full overflow-hidden bg-gray-200 dark:bg-gray-700"
              style={{ width: '40px' }}
            >
              <motion.div
                className="h-full rounded-full"
                style={{
                  backgroundColor: step.color,
                  width: useTransform(
                    scrollYProgress,
                    [i / steps.length, (i + 1) / steps.length],
                    ["0%", "100%"]
                  ),
                }}
              />
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}

function StepContent({ 
  step, 
  index,
  scrollYProgress 
}: { 
  step: typeof steps[0]; 
  index: number;
  scrollYProgress: ReturnType<typeof useScroll>["scrollYProgress"];
}) {
  const stepStart = index / steps.length;
  const stepEnd = (index + 1) / steps.length;
  const stepMiddle = (stepStart + stepEnd) / 2;

  return (
    <motion.div
      className="max-w-lg"
      style={{
        opacity: useTransform(
          scrollYProgress,
          [stepStart, stepStart + 0.15, stepEnd - 0.15, stepEnd],
          [0.3, 1, 1, 0.3]
        ),
        x: useTransform(
          scrollYProgress,
          [stepStart, stepStart + 0.2, stepEnd - 0.2, stepEnd],
          [-30, 0, 0, 30]
        ),
      }}
    >
      <motion.span
        className="text-6xl lg:text-7xl font-bold text-gray-200 dark:text-gray-800 block mb-4"
        style={{
          color: useTransform(
            scrollYProgress,
            [stepStart, stepMiddle, stepEnd],
            ["#e5e7eb", step.color, "#e5e7eb"]
          ),
        }}
      >
        {step.number}
      </motion.span>
      <h3 className="text-2xl lg:text-3xl font-semibold text-gray-900 dark:text-white mb-4">
        {step.title}
      </h3>
      <p className="text-gray-500 dark:text-gray-400 leading-relaxed text-sm lg:text-base">
        {step.description}
      </p>
    </motion.div>
  );
}
