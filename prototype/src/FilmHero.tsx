import { ArrowLeft, Star } from "lucide-react";
import type { ReactNode } from "react";
import type { Media } from "./data";
import { useNova } from "./session";
import { Art, IconBtn } from "./ui";

export function FilmHero({
  media,
  detail = false,
  subheading = false,
  selector,
  children,
}: {
  media: Media;
  detail?: boolean;
  subheading?: boolean;
  selector?: ReactNode;
  children: ReactNode;
}) {
  const n = useNova();
  const Title = subheading ? "h2" : "h1";
  return (
    <section
      className={detail ? "film-hero film-hero-detail" : "film-hero"}
      aria-label={
        detail ? n.t(media.name) : n.tr("العمل البارز", "Featured title")
      }
    >
      <div className="film-hero-frame">
        <Art media={media} />
        {selector}
      </div>
      {detail && (
        <div className="film-hero-back">
          <IconBtn label={n.tr("رجوع", "Back")} onClick={n.back}>
            <ArrowLeft className="direction" />
          </IconBtn>
        </div>
      )}
      <div className="film-hero-caption">
        <div className="film-hero-facts">
          <span>{n.t(media.genre)}</span>
          <span>{media.year}</span>
          <span>
            {media.mins} {n.tr("دقيقة", "min")}
          </span>
          <bdi className="age">{media.age}</bdi>
          {detail && (
            <span
              className="score"
              aria-label={n.tr("التقييم", "Rating") + " " + media.score}
            >
              <Star size={15} />
              {media.score}
            </span>
          )}
        </div>
        <Title className="film-hero-title">{n.t(media.name)}</Title>
        <p className="film-hero-story">{n.t(media.story)}</p>
        <div className="actions">{children}</div>
      </div>
    </section>
  );
}
