import type { Route } from "./+types/home";

export function meta({}: Route.MetaArgs) {
  return [
    { title: "Mission Console | NASA Space Apps 2026" },
    {
      name: "description",
      content: "Тренажер юного астронавта / Junior Astronaut Mission Trainer",
    },
  ];
}

export default function Home() {
  return (
    <main>
      <p className="eyebrow" lang="en">
        NASA Space Apps 2026
      </p>
      <h1 lang="en">Mission Console</h1>
      <p>Тренажер юного астронавта</p>
      <p lang="en">Junior Astronaut Mission Trainer</p>
      <p className="status">
        Підготовка до запуску / <span lang="en">Preparing for launch</span>
      </p>
    </main>
  );
}
