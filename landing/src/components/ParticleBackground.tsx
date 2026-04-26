"use client";

import { useRef, useMemo } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import * as THREE from "three";

function Particles() {
  const mesh = useRef<THREE.Points>(null);
  const mouseRef = useRef({ x: 0, y: 0 });

  const count = 1000;

  const [positions, velocities] = useMemo(() => {
    const positions = new Float32Array(count * 3);
    const velocities = new Float32Array(count * 3);

    for (let i = 0; i < count; i++) {
      const i3 = i * 3;
      positions[i3] = (Math.random() - 0.5) * 20;
      positions[i3 + 1] = (Math.random() - 0.5) * 20;
      positions[i3 + 2] = (Math.random() - 0.5) * 20;

      velocities[i3] = (Math.random() - 0.5) * 0.01;
      velocities[i3 + 1] = (Math.random() - 0.5) * 0.01;
      velocities[i3 + 2] = (Math.random() - 0.5) * 0.01;
    }

    return [positions, velocities];
  }, []);

  useFrame((state) => {
    if (!mesh.current) return;

    const positionAttribute = mesh.current.geometry.attributes.position;
    const array = positionAttribute.array as Float32Array;

    for (let i = 0; i < count; i++) {
      const i3 = i * 3;

      array[i3] += velocities[i3];
      array[i3 + 1] += velocities[i3 + 1];
      array[i3 + 2] += velocities[i3 + 2];

      // Mouse interaction
      const dx = array[i3] - mouseRef.current.x * 5;
      const dy = array[i3 + 1] - mouseRef.current.y * 5;
      const dist = Math.sqrt(dx * dx + dy * dy);

      if (dist < 2) {
        array[i3] += dx * 0.01;
        array[i3 + 1] += dy * 0.01;
      }

      // Boundary wrap
      if (array[i3] > 10) array[i3] = -10;
      if (array[i3] < -10) array[i3] = 10;
      if (array[i3 + 1] > 10) array[i3 + 1] = -10;
      if (array[i3 + 1] < -10) array[i3 + 1] = 10;
      if (array[i3 + 2] > 10) array[i3 + 2] = -10;
      if (array[i3 + 2] < -10) array[i3 + 2] = 10;
    }

    positionAttribute.needsUpdate = true;
    mesh.current.rotation.y = state.clock.elapsedTime * 0.05;
  });

  return (
    <points ref={mesh}>
      <bufferGeometry>
        <bufferAttribute
          attach="attributes-position"
          count={count}
          array={positions}
          itemSize={3}
        />
      </bufferGeometry>
      <pointsMaterial
        size={0.03}
        color="#6366f1"
        transparent
        opacity={0.6}
        sizeAttenuation
      />
    </points>
  );
}

function Connections() {
  const linesRef = useRef<THREE.LineSegments>(null);

  const positions = useMemo(() => {
    const positions = new Float32Array(3000 * 3);
    for (let i = 0; i < positions.length; i++) {
      positions[i] = (Math.random() - 0.5) * 10;
    }
    return positions;
  }, []);

  useFrame((state) => {
    if (!linesRef.current) return;
    linesRef.current.rotation.y = state.clock.elapsedTime * 0.02;
    linesRef.current.rotation.x = Math.sin(state.clock.elapsedTime * 0.1) * 0.1;
  });

  return (
    <lineSegments ref={linesRef}>
      <bufferGeometry>
        <bufferAttribute
          attach="attributes-position"
          count={1000}
          array={positions}
          itemSize={3}
        />
      </bufferGeometry>
      <lineBasicMaterial color="#6366f1" transparent opacity={0.1} />
    </lineSegments>
  );
}

export function ParticleBackground() {
  return (
    <div className="fixed inset-0 z-0 pointer-events-none">
      <Canvas
        camera={{ position: [0, 0, 8], fov: 75 }}
        dpr={[1, 2]}
        gl={{ antialias: true, alpha: true }}
      >
        <ambientLight intensity={0.5} />
        <Particles />
        <Connections />
      </Canvas>
    </div>
  );
}
