
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS referral_source text,
  ADD COLUMN IF NOT EXISTS profession text,
  ADD COLUMN IF NOT EXISTS onboarded_at timestamptz,
  ADD COLUMN IF NOT EXISTS invite_code text UNIQUE,
  ADD COLUMN IF NOT EXISTS role text,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE OR REPLACE FUNCTION public.generate_invite_code()
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result TEXT := '';
  i INT;
BEGIN
  FOR i IN 1..6 LOOP
    result := result || substr(chars, 1 + floor(random() * length(chars))::int, 1);
  END LOOP;
  RETURN result;
END;
$$;

CREATE TABLE IF NOT EXISTS public.parent_child_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_user_id UUID NOT NULL,
  child_user_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (parent_user_id, child_user_id),
  CHECK (parent_user_id <> child_user_id)
);

ALTER TABLE public.parent_child_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own links" ON public.parent_child_links;
CREATE POLICY "Users can view their own links"
  ON public.parent_child_links FOR SELECT
  USING (auth.uid() = parent_user_id OR auth.uid() = child_user_id);

DROP POLICY IF EXISTS "Users can create links involving themselves" ON public.parent_child_links;
CREATE POLICY "Users can create links involving themselves"
  ON public.parent_child_links FOR INSERT
  WITH CHECK (auth.uid() = parent_user_id OR auth.uid() = child_user_id);

DROP POLICY IF EXISTS "Users can delete their own links" ON public.parent_child_links;
CREATE POLICY "Users can delete their own links"
  ON public.parent_child_links FOR DELETE
  USING (auth.uid() = parent_user_id OR auth.uid() = child_user_id);

CREATE OR REPLACE FUNCTION public.find_profile_by_invite_code(_code TEXT)
RETURNS TABLE(id UUID, profession TEXT, display_name TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, profession, display_name
  FROM public.profiles
  WHERE invite_code = _code
  LIMIT 1;
$$;

REVOKE EXECUTE ON FUNCTION public.find_profile_by_invite_code(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.find_profile_by_invite_code(TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.generate_invite_code() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_invite_code() TO authenticated;
