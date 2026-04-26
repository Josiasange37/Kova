"use client";

import { useEffect, useRef } from "react";
import { motion, useInView } from "framer-motion";
import gsap from "gsap";

interface AnimatedTextProps {
  children: string;
  className?: string;
  delay?: number;
  once?: boolean;
}

export function AnimatedText({ 
  children, 
  className = "", 
  delay = 0,
  once = true 
}: AnimatedTextProps) {
  const ref = useRef<HTMLDivElement>(null);
  const isInView = useInView(ref, { once, margin: "-100px" });

  const words = children.split(" ");

  return (
    <div ref={ref} className={className}>
      {words.map((word, i) => (
        <motion.span
          key={i}
          initial={{ opacity: 0, y: 50, rotateX: -90 }}
          animate={isInView ? { opacity: 1, y: 0, rotateX: 0 } : {}}
          transition={{
            duration: 0.6,
            delay: delay + i * 0.05,
            ease: [0.16, 1, 0.3, 1],
          }}
          className="inline-block mr-[0.25em]"
          style={{ transformOrigin: "center bottom" }}
        >
          {word}
        </motion.span>
      ))}
    </div>
  );
}

interface SplitTextProps {
  children: string;
  className?: string;
}

export function SplitText({ children, className = "" }: SplitTextProps) {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!containerRef.current) return;

    const chars = containerRef.current.querySelectorAll(".char");

    gsap.fromTo(
      chars,
      {
        opacity: 0,
        y: 100,
        rotateX: -90,
      },
      {
        opacity: 1,
        y: 0,
        rotateX: 0,
        duration: 1,
        stagger: 0.02,
        ease: "power4.out",
        scrollTrigger: {
          trigger: containerRef.current,
          start: "top 80%",
          end: "top 50%",
        },
      }
    );
  }, []);

  const words = children.split(" ");

  return (
    <div ref={containerRef} className={className}>
      {words.map((word, wordIndex) => (
        <span key={wordIndex} className="inline-block mr-[0.25em]">
          {word.split("").map((char, charIndex) => (
            <span
              key={charIndex}
              className="char inline-block"
              style={{ transformOrigin: "center bottom" }}
            >
              {char}
            </span>
          ))}
        </span>
      ))}
    </div>
  );
}
